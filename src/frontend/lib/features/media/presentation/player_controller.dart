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
    required MediaRepository repository,
    void Function(Object error)? onStreamFailure,
    Logger? logger,
  })  : _repository = repository,
        _onStreamFailure = onStreamFailure,
        _logger = logger ?? Logger('PlayerController');

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

  bool get canGoNext =>
      hasTrack &&
      !isBusy &&
      (activeQueueIndex ?? -1) < _queue.tracks.length - 1;
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

    _pendingStart = true;
    await _runCommand(() => _repository.startTrack(track.path));
  }

  Future<void> playPlaylist(
      MediaPlaylist playlist, List<MediaLibraryTrack> tracks) async {
    if (tracks.isEmpty || isBusy) {
      return;
    }

    _queue = MediaQueue(
      origin: MediaQueueOrigin.playlist,
      playlistId: playlist.id,
      playlistName: playlist.name,
      tracks: tracks,
    );
    _pendingStart = true;
    await _runCommand(() => _repository.startPlaylist(playlist.id));
  }

  Future<void> stop() => _runCommand(_repository.stop);

  Future<void> next() async {
    if (!canGoNext) {
      return;
    }
    await _runCommand(_repository.next);
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
    await _runCommand(_repository.previous);
  }

  void dismissTransientMessage() {
    if (_transientMessageKey == null) {
      return;
    }
    _transientMessageKey = null;
    notifyListeners();
  }

  Future<void> _runCommand(Future<void> Function() command) async {
    _isCommandInFlight = true;
    notifyListeners();

    try {
      await command();
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
    _status = state.status;
    _mediaPath = state.mediaPath;
    _anchorPosition = state.position;
    _anchorStartedAt = clock.now();
    await _restorePlaylistIfNeeded(state.playlistId);
    _currentTrack = _resolveTrack(state.mediaPath);

    if (_status == PlaybackStatus.playing) {
      _startTicker();
    } else {
      _stopTicker();
    }

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
      _logger.warning('GetPlaylist($playlistId) during state restore failed: '
          '${error.message}');
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
