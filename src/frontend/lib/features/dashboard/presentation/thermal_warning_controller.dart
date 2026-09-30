import 'dart:async';

import 'package:carnine_frontend/features/dashboard/data/thermal_status_source.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Decides when the overheating warning is on screen (#70).
///
/// It comes up when the backend reports the CPU overheated and stays until
/// the user confirms it, on whatever page they are. Once confirmed it stays
/// away while the CPU is still hot - reconnects report the same status
/// again - and only comes back after the backend reported it cool and then
/// overheated once more.
class ThermalWarningController extends ChangeNotifier {
  ThermalWarningController({ThermalStatusSource? source, Logger? logger})
    : _source = source ?? GrpcThermalStatusSource(),
      _logger = logger ?? Logger('ThermalWarningController');

  final ThermalStatusSource _source;
  final Logger _logger;
  StreamSubscription<ThermalStatus>? _subscription;
  ThermalStatus _status = ThermalStatus.normal;
  bool _confirmed = false;

  ThermalStatus get status => _status;

  bool get showsWarning => _status.overheated && !_confirmed;

  void start() {
    _subscription ??= _source.statuses.listen(_onStatus);
  }

  void confirm() {
    if (!showsWarning) {
      return;
    }
    _logger.info('Overheating warning confirmed');
    _confirmed = true;
    notifyListeners();
  }

  void _onStatus(ThermalStatus status) {
    if (status.overheated && !_status.overheated) {
      _logger.warning('CPU overheated: ${status.cpuCelsius} °C');
    }
    if (!status.overheated) {
      _confirmed = false;
    }
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_source.dispose());
    super.dispose();
  }
}
