import 'dart:async';

import 'package:carnine_frontend/core/platform/backend_heartbeat.dart';
import 'package:carnine_frontend/features/media/data/grpc_media_repository.dart';
import 'package:carnine_frontend/features/media/domain/media_repository.dart';
import 'package:carnine_frontend/features/media/presentation/audio_controller.dart';
import 'package:carnine_frontend/features/media/presentation/library_controller.dart';
import 'package:carnine_frontend/features/media/presentation/player_controller.dart';
import 'package:carnine_frontend/features/media/presentation/playlist_controller.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

/// Connection status towards the backend media services.
enum MediaConnectionStatus { connecting, online, offline }

/// Composition root for the media feature: owns the repository and the
/// player/library/playlist sub-controllers, plus navigation between the
/// player and its library-action sub-pages, and the connection-loss
/// reconnect loop shared by all three sub-controllers.
class MediaController extends ChangeNotifier {
  MediaController({
    MediaRepository? repository,
    PlayerController? player,
    LibraryController? library,
    PlaylistController? playlists,
    AudioController? audio,
    Logger? logger,

    /// `null` runs without a heartbeat; only tests that do not care about
    /// the connection do that.
    Duration? heartbeatInterval = BackendHeartbeat.defaultInterval,
    Duration heartbeatTimeout = BackendHeartbeat.defaultTimeout,
  }) : _repository = repository ?? GrpcMediaRepository(),
       _logger = logger ?? Logger('MediaController'),
       _aliveTimeout = heartbeatTimeout {
    if (heartbeatInterval != null) {
      _heartbeat = BackendHeartbeat(
        check: _repository.checkAlive,
        onFailure: _onHeartbeatFailure,
        interval: heartbeatInterval,
        timeout: heartbeatTimeout,
      );
    }
    player =
        player ??
        PlayerController(
          repository: _repository,
          onStreamFailure: reportStreamFailure,
        );
    library =
        library ??
        LibraryController(
          repository: _repository,
          onStreamFailure: reportStreamFailure,
        );
    playlists =
        playlists ??
        PlaylistController(
          repository: _repository,
          onStreamFailure: reportStreamFailure,
        );
    audio =
        audio ??
        AudioController(
          repository: _repository,
          onStreamFailure: reportStreamFailure,
        );
    this.player = player;
    this.library = library;
    this.playlists = playlists;
    this.audio = audio;
    // The player stream opens before the library loads, so a paused track
    // can arrive before the library knows it (#81).
    this.library.addListener(this.player.resolveTrackFromLibrary);
  }

  static const _initialReconnectDelay = Duration(milliseconds: 500);
  static const _maxReconnectDelay = Duration(seconds: 5);

  final MediaRepository _repository;
  final Logger _logger;
  final Duration _aliveTimeout;
  BackendHeartbeat? _heartbeat;

  late final PlayerController player;
  late final LibraryController library;
  late final PlaylistController playlists;
  late final AudioController audio;

  bool _isQueueExpanded = true;
  MediaLibraryAction? _openLibraryAction;
  MediaConnectionStatus _connection = MediaConnectionStatus.connecting;
  Timer? _reconnectTimer;
  Duration _nextReconnectDelay = _initialReconnectDelay;
  bool _started = false;

  /// Stream failures reported while already offline. [_reconnect] compares
  /// it before and after re-opening the streams: a stream that dies while
  /// the backend is still coming up must not be forgotten (#44).
  int _failuresWhileOffline = 0;

  bool get isQueueExpanded => _isQueueExpanded;
  MediaLibraryAction? get openLibraryAction => _openLibraryAction;
  MediaConnectionStatus get connection => _connection;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    await player.start();
    await library.start();
    await audio.start();
    unawaited(playlists.start());
    _connection = MediaConnectionStatus.online;
    _heartbeat?.start();
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _heartbeat?.stop();
    library.removeListener(player.resolveTrackFromLibrary);
    player.dispose();
    library.dispose();
    playlists.dispose();
    audio.dispose();
    unawaited(_repository.dispose());
    super.dispose();
  }

  void toggleQueueExpanded() {
    _isQueueExpanded = !_isQueueExpanded;
    _logger.info(
      _isQueueExpanded ? 'Queue panel expanded' : 'Queue panel collapsed',
    );
    notifyListeners();
  }

  void showLibraryAction(MediaLibraryAction action) {
    if (action == _openLibraryAction) {
      return;
    }

    _openLibraryAction = action;
    _logger.info('Opening media library action ${action.name}');
    notifyListeners();
  }

  void closeLibraryAction() {
    final current = _openLibraryAction;
    if (current == null) {
      return;
    }

    _openLibraryAction = null;
    _logger.info('Closing media library action ${current.name}');
    notifyListeners();
  }

  /// Called by any sub-controller when its stream reports a connection-loss
  /// failure. Owns the single reconnect loop for the whole media feature.
  void reportStreamFailure(Object error) {
    if (_connection == MediaConnectionStatus.offline) {
      _failuresWhileOffline++;
      return;
    }

    _logger.warning('Media backend connection lost: $error');
    _heartbeat?.stop();
    _connection = MediaConnectionStatus.offline;
    _nextReconnectDelay = _initialReconnectDelay;
    notifyListeners();
    _scheduleReconnect();
  }

  /// The backend holds its socket but stopped answering (#58). Its streams
  /// would wait for it forever, so the channel is closed hard: they fail now,
  /// while already offline, and the reconnect loop takes over.
  void _onHeartbeatFailure(Object error) {
    _logger.warning('Media backend stopped answering: $error');
    reportStreamFailure(error);
    unawaited(_repository.reconnect());
  }

  /// Cancels any pending backoff and reconnects immediately - wired to the
  /// retry action on the offline state view.
  Future<void> retryNow() async {
    _reconnectTimer?.cancel();
    await _reconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_nextReconnectDelay, () {
      unawaited(_reconnect());
    });
    _nextReconnectDelay = Duration(
      milliseconds: (_nextReconnectDelay.inMilliseconds * 2).clamp(
        0,
        _maxReconnectDelay.inMilliseconds,
      ),
    );
  }

  Future<void> _reconnect() async {
    _logger.info('Attempting to reconnect to the media backend');
    final failuresBefore = _failuresWhileOffline;

    try {
      await _repository.reconnect();
      // A frozen backend accepts the new connection but never answers, and
      // re-opened streams do not fail; only a call with a deadline tells.
      await _repository.checkAlive().timeout(_aliveTimeout);
      await player.reconnect();
      await library.reconnect();
      await playlists.reconnect();
      await audio.reconnect();
      if (_failuresWhileOffline != failuresBefore) {
        throw StateError('A media stream failed while reconnecting');
      }
      _connection = MediaConnectionStatus.online;
      _nextReconnectDelay = _initialReconnectDelay;
      _heartbeat?.start();
      notifyListeners();
    } catch (error, stackTrace) {
      _logger.warning('Reconnect attempt failed', error, stackTrace);
      _scheduleReconnect();
    }
  }
}

/// Library quick actions surfaced below the queue, each opening its own
/// sub-page: create a playlist, browse individual library tracks, or browse
/// existing playlists.
enum MediaLibraryAction { create, library, collections }
