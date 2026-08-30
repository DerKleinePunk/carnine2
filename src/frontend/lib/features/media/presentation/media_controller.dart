import 'dart:async';

import 'package:carnine_frontend/features/media/data/grpc_media_repository.dart';
import 'package:carnine_frontend/features/media/domain/media_repository.dart';
import 'package:carnine_frontend/features/media/presentation/library_controller.dart';
import 'package:carnine_frontend/features/media/presentation/player_controller.dart';
import 'package:carnine_frontend/features/media/presentation/playlist_controller.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

/// Connection status towards the backend media services.
enum MediaConnectionStatus {
  connecting,
  online,
  offline,
}

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
    Logger? logger,
  })  : _repository = repository ?? GrpcMediaRepository(),
        _logger = logger ?? Logger('MediaController') {
    player = player ??
        PlayerController(
            repository: _repository, onStreamFailure: reportStreamFailure);
    library = library ??
        LibraryController(
            repository: _repository, onStreamFailure: reportStreamFailure);
    playlists = playlists ??
        PlaylistController(
            repository: _repository, onStreamFailure: reportStreamFailure);
    this.player = player;
    this.library = library;
    this.playlists = playlists;
  }

  static const _initialReconnectDelay = Duration(milliseconds: 500);
  static const _maxReconnectDelay = Duration(seconds: 5);

  final MediaRepository _repository;
  final Logger _logger;

  late final PlayerController player;
  late final LibraryController library;
  late final PlaylistController playlists;

  bool _isQueueExpanded = true;
  MediaLibraryAction? _openLibraryAction;
  MediaConnectionStatus _connection = MediaConnectionStatus.connecting;
  Timer? _reconnectTimer;
  Duration _nextReconnectDelay = _initialReconnectDelay;
  bool _started = false;

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
    unawaited(playlists.loadPlaylists());
    _connection = MediaConnectionStatus.online;
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    player.dispose();
    library.dispose();
    playlists.dispose();
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
      return;
    }

    _logger.warning('Media backend connection lost: $error');
    _connection = MediaConnectionStatus.offline;
    _nextReconnectDelay = _initialReconnectDelay;
    notifyListeners();
    _scheduleReconnect();
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
      milliseconds: (_nextReconnectDelay.inMilliseconds * 2)
          .clamp(0, _maxReconnectDelay.inMilliseconds),
    );
  }

  Future<void> _reconnect() async {
    _logger.info('Attempting to reconnect to the media backend');

    try {
      await _repository.reconnect();
      await player.reconnect();
      await library.reconnect();
      _connection = MediaConnectionStatus.online;
      _nextReconnectDelay = _initialReconnectDelay;
      notifyListeners();
    } catch (error, stackTrace) {
      _logger.warning('Reconnect attempt failed', error, stackTrace);
      _scheduleReconnect();
    }
  }
}

/// Library quick actions surfaced below the queue, each opening its own
/// sub-page: create a playlist, or browse the library and playlists.
enum MediaLibraryAction {
  create,
  collections,
}
