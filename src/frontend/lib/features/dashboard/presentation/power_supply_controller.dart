import 'dart:async';

import 'package:carnine_frontend/features/dashboard/data/power_supply_source.dart';
import 'package:flutter/foundation.dart';

/// Holds the latest power supply status for the top bar and the notice.
class PowerSupplyController extends ChangeNotifier {
  PowerSupplyController({PowerSupplySource? source})
    : _source = source ?? GrpcPowerSupplySource();

  final PowerSupplySource _source;
  StreamSubscription<PowerSupplyStatus>? _subscription;
  PowerSupplyStatus _status = PowerSupplyStatus.none;

  PowerSupplyStatus get status => _status;

  void start() {
    _subscription ??= _source.statuses.listen((status) {
      _status = status;
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
