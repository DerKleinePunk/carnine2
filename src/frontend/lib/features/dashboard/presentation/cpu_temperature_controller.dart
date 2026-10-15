import 'dart:async';

import 'package:carnine_frontend/features/dashboard/data/cpu_temperature_source.dart';
import 'package:flutter/foundation.dart';

/// Holds the latest CPU temperature for the vehicle tile of the start page.
class CpuTemperatureController extends ChangeNotifier {
  CpuTemperatureController({CpuTemperatureSource? source})
    : _source = source ?? GrpcCpuTemperatureSource();

  final CpuTemperatureSource _source;
  StreamSubscription<double?>? _subscription;
  double? _celsius;

  /// In °C; `null` until the first sample, and without a thermal zone.
  double? get celsius => _celsius;

  void start() {
    _subscription ??= _source.temperatures.listen((celsius) {
      _celsius = celsius;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_source.dispose());
    super.dispose();
  }
}
