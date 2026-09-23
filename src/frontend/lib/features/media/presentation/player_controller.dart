import 'dart:async';

import 'package:carnine_frontend/features/media/domain/media_backend_exception.dart';
import 'package:carnine_frontend/features/media/domain/media_repository.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/domain/models/media_queue.dart';
import 'package:carnine_frontend/features/media/domain/models/player_event_update.dart';
import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Presentation controller for playback state and transport controls.
///
/// Position is derived, never accumulated: the backend reports a wall-clock
/// authoritative position on every event, and a local 250ms ticker only
/// re-derives the elapsed time against that anchor while playing. This keeps
/// a 1Hz `position_changed` event from double-counting against the ticker.
///
/// Elapsed time is measured via `package:clock`'s [Clock.now] rather than a
/// raw [Stopwatch], so tests can advance it deterministically with
/// `package:fake_async` - a [Stopwatch] reads the real hardware clock and
/// cannot be faked.
class PlayerController extends ChangeNotifier {
  PlayerController({
    required this._repository,
    this._onStreamFailure,
    Logger? logger,
  }) : _logger = logger ?? Logger('PlayerController');

  static const _tickInterval = Duration(milliseconds: 250);

  final MediaRepository _repository;
  final void Function(Object error)? _onStreamFailure;
  final Logger _logger;

  PlaybackStatus _status = PlaybackStatus.stopped;
  String _mediaPath = '';
  Duration _anchorPosition = Duration.zero;
  DateTime? _anchorStartedAt;
  MediaQueue _queue = const MediaQueue.empty();
  MediaLibraryTrack? _currentTrack;
  bool _isCommandInFlight = false;
  bool _pendingStart = false;
  AppTextKey? _transientMessageKey;
  int _lastNotifiedPositionSeconds = -1;
  MediaRepeatMode _repeatMode = MediaRepeatMode.off;
  bool _shuffleEnabled = false;

  // Mirrors the backend's shuffle bag walk (`media_player.rs`
  // `resolve_next_shuffled_index`/`shuffle_position`): a plain position into
  // a fixed-but-unknown-to-us shuffled order, 0 at the track shuffle was
  // turned on (or a new queue loaded) at, capped at `queue length - 1`. The
  // backend doesn't expose its actual shuffle order or position, so this is
  // a best-effort client-side mirror for the single-client case the app
  // otherwise assumes (`docs/20-media-backend-plan.md` explicitly defers
  // multi-client support) - a direct `playQueueEntry` jump can desync it,
  // same as it would desync the backend's own bag.
  int _shufflePosition = 0;
  bool _pendingShuffleStepBack = false;

  // Cover art is fetched once per track and kept for the app's lifetime -
  // the backend cover cache is immutable per file (`database.rs`
  // `upsert_media` only ever replaces the whole row on rescan), so there is
  // no staleness to guard against, and re-visiting a track is free.
  final Map<int, Uint8List?> _coverArtCache = {};
  int? _coverArtTrackId;

  StreamSubscription<PlayerEventUpdate>? _subscription;
  Timer? _ticker;

  PlaybackStatus get status => _status;
  bool get isPlaying => _status == PlaybackStatus.playing;
  bool get hasTrack => _currentTrack != null;
  bool get isBusy => _isCommandInFlight;
  MediaLibraryTrack? get currentTrack => _currentTrack;
  MediaQueue get queue => _queue;
  int? get activeQueueIndex => _queue.indexOfPath(_mediaPath);
  AppTextKey? get transientMessageKey => _transientMessageKey;
  MediaRepeatMode get repeatMode => _repeatMode;
  bool get shuffleEnabled => _shuffleEnabled;

  /// The current track's cover art, once fetched - `null` while loading, not
  /// yet requested, or the track has none. Callers show their icon fallback
  /// for `null` regardless of which of those it is.
  Uint8List? get currentTrackCoverArt =>
      _currentTrack == null ? null : _coverArtCache[_currentTrack!.id];

  /// With repeat (queue or track) active, the backend always has a next
  /// track to advance to - either it loops the queue or replays the current
  /// entry - so the boundary check only applies with repeat off. With
  /// shuffle (and repeat off), the boundary is [_shufflePosition] against the
  /// queue length rather than [activeQueueIndex] - the currently playing
  /// track's position in the *original* queue order says nothing about how
  /// many of the shuffled tracks have actually been played yet.
  bool get canGoNext =>
      hasTrack &&
      !isBusy &&
      (_repeatMode != MediaRepeatMode.off ||
          (_shuffleEnabled
              ? _shufflePosition < _queue.tracks.length - 1
              : (activeQueueIndex ?? -1) < _queue.tracks.length - 1));
  bool get canGoPrevious => hasTrack && !isBusy && (activeQueueIndex ?? 0) > 0;

  Duration get duration => _currentTrack?.duration ?? Duration.zero;

  double get progress {
    final total = duration;
    if (total <= Duration.zero) {
      return 0;
    }
    return (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  /// The current playback position, derived from the last backend anchor
  /// plus locally elapsed time - never accumulated across events. Clamped to
  /// the known track duration so a backend that never notices end-of-track
  /// doesn't run the timeline past it.
  Duration get position {
    final startedAt = _anchorStartedAt;
    final elapsed = (_status == PlaybackStatus.playing && startedAt != null)
        ? clock.now().difference(startedAt)
        : Duration.zero;
    final base = _anchorPosition + elapsed;
    final max = _currentTrack?.duration;
    if (max != null && max > Duration.zero && base > max) {
      return max;
    }
    return base;
  }

  /// Subscribes to the player event stream. Safe to call again after
  /// [reconnect] tore the previous subscription down.
  Future<void> start() async {
    await _subscription?.cancel();
    _subscription = _repository.playerEvents().listen(
      _onEvent,
      onError: _onStreamError,
      onDone: _onStreamDone,
    );
  }

  /// Re-subscribes to the player event stream after the underlying
  /// transport was rebuilt. The stream always opens with a `snapshot`
  /// event, so no separate re-seed call is needed.
  Future<void> reconnect() => start();

  @override
  void dispose() {
    _subscription?.cancel();
    _stopTicker();
    super.dispose();
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await _runCommand(_repository.pause);
    } else if (hasTrack) {
      await _runCommand(_repository.resume);
    }
  }

  Future<void> playTrack(MediaLibraryTrack track) async {
    if (!track.isPlayable || isBusy) {
      return;
    }

    _shufflePosition = 0;
    _pendingStart = true;
    await _runCommand(() => _repository.startTrack(track.path));
  }

  /// Returns whether playback actually started - `false` for an empty
  /// playlist, while busy, or on a backend failure.
  Future<bool> playPlaylist(
    MediaPlaylist playlist,
    List<MediaLibraryTrack> tracks,
  ) async {
    if (tracks.isEmpty || isBusy) {
      return false;
    }

    _queue = MediaQueue(
      origin: MediaQueueOrigin.playlist,
      playlistId: playlist.id,
      playlistName: playlist.name,
      tracks: tracks,
    );
    // A fresh queue always starts a fresh shuffle bag on the backend
    // (`media_player.rs` reshuffles from the new current track whenever a
    // playlist loads while shuffle is on).
    _shufflePosition = 0;
    _pendingStart = true;
    return _runCommand(() => _repository.startPlaylist(playlist.id));
  }

  Future<void> stop() => _runCommand(_repository.stop);

  Future<void> next() async {
    if (!canGoNext) {
      return;
    }
    await _runCommand(_repository.next);
  }

  Future<void> playQueueEntry(int index) async {
    if (isBusy || index < 0 || index >= _queue.tracks.length) {
      return;
    }
    await _runCommand(() => _repository.playQueueEntry(index));
  }

  Future<void> toggleShuffle() async {
    final next = !_shuffleEnabled;
    // Optimistic: flips immediately so the toggle feels instant, then the
    // next `PlayerState` (from this call's own event, or any other) becomes
    // the source of truth - same reconciliation the backend already forces
    // on every other command in this controller.
    _shuffleEnabled = next;
    notifyListeners();
    await _runCommand(() => _repository.setShuffleMode(next));
  }

  Future<void> cycleRepeat() async {
    final next = switch (_repeatMode) {
      MediaRepeatMode.off => MediaRepeatMode.queue,
      MediaRepeatMode.queue => MediaRepeatMode.track,
      MediaRepeatMode.track => MediaRepeatMode.off,
    };
    _repeatMode = next;
    notifyListeners();
    await _runCommand(() => _repository.setRepeatMode(next));
  }

  Future<void> previous() async {
    if (!hasTrack || isBusy) {
      return;
    }
    if (position >= const Duration(seconds: 3)) {
      await _runCommand(_repository.restartCurrentTrack);
      return;
    }
    if (!canGoPrevious) {
      return;
    }
    if (_shuffleEnabled && _repeatMode == MediaRepeatMode.off) {
      _pendingShuffleStepBack = true;
    }
    await _runCommand(_repository.previous);
  }

  void dismissTransientMessage() {
    if (_transientMessageKey == null) {
      return;
    }
    _transientMessageKey = null;
    notifyListeners();
  }

  /// Returns whether [command] actually succeeded - most callers just await
  /// this for its side effects, but a caller that needs to know (e.g.
  /// navigating to the player only once a playlist actually started) can
  /// use the result instead of guessing from other state.
  Future<bool> _runCommand(Future<void> Function() command) async {
    _isCommandInFlight = true;
    notifyListeners();
    var succeeded = false;

    try {
      await command();
      succeeded = true;
    } on MediaBackendException catch (error) {
      _pendingStart = false;
      // Only an actually-offline backend should flip the whole screen into
      // the offline/reconnect state - every other failure kind (queue
      // boundary, a single slow call that hit its deadline, a bad request)
      // is local to this one command and must not tear down the channel.
      if (error.kind == MediaErrorKind.precondition) {
        _transientMessageKey = AppTextKey.mediaNoAdjacentTrack;
      } else {
        _transientMessageKey = AppTextKey.mediaCommandFailed;
        if (error.kind == MediaErrorKind.offline) {
          _onStreamFailure?.call(error);
        }
      }
      _logger.warning('Player command failed: ${error.message}');
    } finally {
      _isCommandInFlight = false;
      notifyListeners();
    }
    return succeeded;
  }

  void _onEvent(PlayerEventUpdate event) {
    switch (event.kind) {
      case PlayerEventKind.snapshot:
      case PlayerEventKind.positionChanged:
      case PlayerEventKind.playbackStarted:
      case PlayerEventKind.resumed:
      case PlayerEventKind.paused:
      case PlayerEventKind.trackChanged:
        final state = event.state;
        if (state != null) {
          unawaited(_applyState(state));
        }
      case PlayerEventKind.stopped:
        if (_pendingStart) {
          // The synthetic Stop issued by startTrack()/startPlaylist() before
          // the real Play - swallow it so the player doesn't blank for a
          // frame between the two backend calls.
          _pendingStart = false;
          return;
        }
        _status = PlaybackStatus.stopped;
        _anchorPosition = Duration.zero;
        _anchorStartedAt = null;
        _stopTicker();
        notifyListeners();
      case PlayerEventKind.queueFinished:
        // The last track ran out. The backend is already stopped; without this
        // the UI kept showing playback until some other event arrived.
        _status = PlaybackStatus.stopped;
        _anchorPosition = Duration.zero;
        _anchorStartedAt = null;
        _stopTicker();
        notifyListeners();
      case PlayerEventKind.error:
        _transientMessageKey = AppTextKey.mediaCommandFailed;
        _logger.severe('Player reported an error: ${event.message}');
        notifyListeners();
      case PlayerEventKind.unknown:
        _logger.info('Ignoring unknown player event: ${event.message}');
    }
  }

  Future<void> _applyState(PlayerSnapshot state) async {
    _pendingStart = false;
    final previousMediaPath = _mediaPath;
    final shuffleJustEnabled = !_shuffleEnabled && state.shuffleEnabled;
    final previousPlaylistId = _queue.playlistId;
    _status = state.status;
    _mediaPath = state.mediaPath;
    _anchorPosition = state.position;
    _anchorStartedAt = clock.now();
    _repeatMode = state.repeatMode;
    _shuffleEnabled = state.shuffleEnabled;
    await _restorePlaylistIfNeeded(state.playlistId);
    _currentTrack = _resolveTrack(state.mediaPath);
    unawaited(_ensureCoverArtLoaded(_currentTrack));
    _updateShufflePosition(
      previousMediaPath: previousMediaPath,
      shuffleJustEnabled: shuffleJustEnabled,
      playlistJustChanged: _queue.playlistId != previousPlaylistId,
    );

    if (_status == PlaybackStatus.playing) {
      _startTicker();
    } else {
      _stopTicker();
    }

    notifyListeners();
  }

  /// Keeps [_shufflePosition] tracking the backend's own shuffle bag walk
  /// (see the field doc). Resets to 0 exactly when the backend would
  /// re-pin its shuffle order to the current track - shuffle just turned on,
  /// or a different playlist was loaded - and otherwise steps by one on an
  /// actual track change, forward unless it was this client's own
  /// [previous] call.
  void _updateShufflePosition({
    required String previousMediaPath,
    required bool shuffleJustEnabled,
    required bool playlistJustChanged,
  }) {
    final steppedBack = _pendingShuffleStepBack;
    _pendingShuffleStepBack = false;

    if (shuffleJustEnabled || playlistJustChanged) {
      _shufflePosition = 0;
      return;
    }

    final trackChanged =
        _mediaPath.isNotEmpty && _mediaPath != previousMediaPath;
    if (!_shuffleEnabled ||
        _repeatMode != MediaRepeatMode.off ||
        !trackChanged) {
      return;
    }

    final maxIndex = _queue.tracks.length - 1;
    if (maxIndex < 0) {
      return;
    }
    _shufflePosition = (_shufflePosition + (steppedBack ? -1 : 1)).clamp(
      0,
      maxIndex,
    );
  }

  /// Fetches and caches [track]'s cover art if it has one and this is the
  /// first time this controller has seen that track id.
  Future<void> _ensureCoverArtLoaded(MediaLibraryTrack? track) async {
    if (track == null ||
        !track.hasCoverArt ||
        _coverArtCache.containsKey(track.id)) {
      return;
    }

    // Guards against two overlapping fetches for the same track (e.g. a
    // `positionChanged` event arriving while the first fetch is in flight).
    if (_coverArtTrackId == track.id) {
      return;
    }
    _coverArtTrackId = track.id;

    final bytes = await _repository.getTrackCoverArt(track.id);
    _coverArtCache[track.id] = bytes;
    notifyListeners();
  }

  Future<void> _restorePlaylistIfNeeded(int? playlistId) async {
    if (playlistId == null || _queue.playlistId == playlistId) {
      return;
    }
    try {
      final playlist = await _repository.getPlaylist(playlistId);
      final tracks = playlist.entries
          .map((entry) => entry.track)
          .whereType<MediaLibraryTrack>()
          .toList();
      _queue = MediaQueue(
        origin: MediaQueueOrigin.playlist,
        playlistId: playlist.id,
        playlistName: playlist.name,
        tracks: tracks,
      );
    } on MediaBackendException catch (error) {
      _logger.warning(
        'GetPlaylist($playlistId) during state restore failed: '
        '${error.message}',
      );
    }
  }

  /// Resolves the current track for [mediaPath], preferring the local queue
  /// (so playlist context survives even if the library cache lags behind)
  /// and falling back to the library cache. When neither has it, the
  /// previously known track is kept sticky rather than cleared - the
  /// backend's `Stop` clears `media_path` but the UI should keep showing
  /// what was last playing.
  MediaLibraryTrack? _resolveTrack(String mediaPath) {
    if (mediaPath.isEmpty) {
      return _currentTrack;
    }

    final fromQueue = _queue.tracks.where((track) => track.path == mediaPath);
    if (fromQueue.isNotEmpty) {
      return fromQueue.first;
    }

    final fromCache = _repository.trackForPath(mediaPath);
    if (fromCache != null) {
      if (_queue.isEmpty) {
        _queue = MediaQueue(
          origin: MediaQueueOrigin.singleTrack,
          playlistId: null,
          playlistName: null,
          tracks: [fromCache],
        );
      }
      return fromCache;
    }

    return _currentTrack;
  }

  void _startTicker() {
    _lastNotifiedPositionSeconds = position.inSeconds;
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickInterval, (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    final seconds = position.inSeconds;
    if (seconds == _lastNotifiedPositionSeconds) {
      return;
    }
    _lastNotifiedPositionSeconds = seconds;
    notifyListeners();
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    _logger.warning('Player event stream failed', error, stackTrace);
    _stopTicker();
    _onStreamFailure?.call(error);
  }

  void _onStreamDone() {
    _logger.info('Player event stream closed');
    _stopTicker();
  }
}
