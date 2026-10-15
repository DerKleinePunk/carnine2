import 'dart:async';

import 'package:carnine_frontend/features/maps/data/map_follow_zoom_store.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:local_map/local_map.dart';
import 'package:logging/logging.dart';

/// The zoom level the map goes to when it follows the car (#131), set in the
/// options and kept by the backend. A change shows on the map at once: the
/// map takes the [MapConfig] from [configFor] and zooms to it.
///
/// Owned by the dashboard, because both the map page and the options use it.
class MapFollowZoomController extends ChangeNotifier {
  MapFollowZoomController({
    this._store,
    this.loadRetryDelays = defaultLoadRetryDelays,
    Logger? logger,
  }) : _logger = logger ?? Logger('MapFollowZoomController');

  /// What the map has when nothing was saved.
  static const int defaultZoom = 16;

  /// The levels the options offer: from the district to single streets.
  static const int minZoom = 14;
  static const int maxZoom = 17;

  /// The pauses between attempts to read the saved zoom while the backend is
  /// not up yet (the interface can start faster than it).
  static const List<Duration> defaultLoadRetryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  static const _errorDuration = Duration(seconds: 4);

  final MapFollowZoomStore? _store;
  final List<Duration> loadRetryDelays;
  final Logger _logger;

  int _zoom = defaultZoom;
  int? _draft;
  bool _changedByUser = false;
  AppTextKey? _errorKey;
  Timer? _errorTimer;
  Timer? _retryTimer;
  bool _disposed = false;

  MapConfig? _configBase;
  int? _configZoom;
  MapConfig? _config;

  /// The level the map follows at: the saved one, [defaultZoom] without.
  int get zoom => _zoom;

  /// The level the slider shows: the one being dragged, else [zoom].
  int get shownZoom => _draft ?? _zoom;

  /// Why the last change failed, shown briefly.
  AppTextKey? get errorKey => _errorKey;

  /// [base] with the follow zoom. The same object as long as neither [base]
  /// nor the level changed: the map zooms again whenever it gets another
  /// config, and a rebuild must not do that.
  MapConfig configFor(MapConfig base) {
    final cached = _config;
    if (cached != null &&
        identical(_configBase, base) &&
        _configZoom == _zoom) {
      return cached;
    }
    _configBase = base;
    _configZoom = _zoom;
    return _config = base.copyWith(followZoom: _zoom.toDouble());
  }

  /// Reads the saved level. While the backend is away it tries again a few
  /// times, and a level the user chose in the meantime is not overwritten.
  Future<void> load() async {
    final store = _store;
    if (store == null) {
      return;
    }
    for (var attempt = 0; ; attempt++) {
      try {
        final saved = await store.loadFollowZoom();
        if (_disposed) {
          return;
        }
        if (!_changedByUser) {
          _zoom = saved == 0 ? defaultZoom : saved;
          notifyListeners();
        }
        return;
      } on Object catch (error) {
        _logger.info('The follow zoom is not available yet: $error');
        if (attempt >= loadRetryDelays.length || _disposed) {
          return;
        }
        final retry = Completer<void>();
        _retryTimer = Timer(loadRetryDelays[attempt], retry.complete);
        await retry.future;
        if (_disposed) {
          return;
        }
      }
    }
  }

  /// While the thumb is dragged: shown at once, not sent.
  void drag(int level) {
    _draft = level;
    notifyListeners();
  }

  /// The thumb is let go: the map goes there at once, and the level is saved.
  /// If saving fails, the map goes back.
  Future<void> commit(int level) async {
    final previous = _zoom;
    _draft = null;
    _changedByUser = true;
    _zoom = level;
    notifyListeners();

    final store = _store;
    if (store == null || level == previous) {
      return;
    }
    try {
      await store.saveFollowZoom(level);
    } on Object catch (error) {
      _logger.warning('Saving the follow zoom failed: $error');
      if (_disposed) {
        return;
      }
      _zoom = previous;
      _errorKey = AppTextKey.mediaCommandFailed;
      _errorTimer?.cancel();
      _errorTimer = Timer(_errorDuration, dismissError);
      notifyListeners();
    }
  }

  void dismissError() {
    if (_errorKey == null) {
      return;
    }
    _errorTimer?.cancel();
    _errorKey = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _errorTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
