import 'dart:async';

import 'package:carnine_frontend/features/maps/data/traffic_setting_store.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// The switch for traffic from the internet on the map, kept by the backend.
///
/// **Off until the user turns it on**: traffic is the only part of CarNine
/// that sends requests out of the car. [apply] hands every change to the map
/// (`MapsController.setTrafficEnabled`); while it is off the map library sends
/// no request at all.
///
/// Owned by the dashboard, because the map page and the options use it.
class TrafficController extends ChangeNotifier {
  TrafficController({
    required this.apply,
    this._store,
    this.loadRetryDelays = defaultLoadRetryDelays,
    Logger? logger,
  }) : _logger = logger ?? Logger('TrafficController');

  /// The pauses between attempts to read the switch while the backend is not
  /// up yet (the interface can start faster than it).
  static const List<Duration> defaultLoadRetryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  static const _errorDuration = Duration(seconds: 4);

  /// Hands the state to the map.
  final void Function(bool enabled) apply;
  final List<Duration> loadRetryDelays;
  final TrafficSettingStore? _store;
  final Logger _logger;

  bool _enabled = false;
  bool _changedByUser = false;
  AppTextKey? _errorKey;
  Timer? _errorTimer;
  Timer? _retryTimer;
  bool _disposed = false;

  /// Whether traffic is on.
  bool get enabled => _enabled;

  /// Why the last change failed, shown briefly.
  AppTextKey? get errorKey => _errorKey;

  /// Reads the saved switch. While the backend is away it tries again a few
  /// times; a switch the user flipped in the meantime is not overwritten.
  /// Without an answer it stays off.
  Future<void> load() async {
    final store = _store;
    if (store == null) {
      return;
    }
    for (var attempt = 0; ; attempt++) {
      try {
        final saved = await store.loadTrafficEnabled();
        if (_disposed) {
          return;
        }
        if (!_changedByUser) {
          _set(saved);
        }
        return;
      } on Object catch (error) {
        _logger.info('The traffic switch is not available yet: $error');
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

  /// The user flips the switch: the map follows at once, and it is saved. If
  /// saving fails, the switch and the map go back.
  Future<void> setEnabled(bool enabled) async {
    final previous = _enabled;
    _changedByUser = true;
    if (enabled == previous) {
      return;
    }
    _set(enabled);

    final store = _store;
    if (store == null) {
      return;
    }
    try {
      await store.saveTrafficEnabled(enabled);
      _logger.info('Traffic from the internet ${enabled ? 'on' : 'off'}');
    } on Object catch (error) {
      _logger.warning('Saving the traffic switch failed: $error');
      if (_disposed) {
        return;
      }
      _set(previous);
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

  void _set(bool enabled) {
    if (enabled == _enabled) {
      return;
    }
    _enabled = enabled;
    apply(enabled);
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
