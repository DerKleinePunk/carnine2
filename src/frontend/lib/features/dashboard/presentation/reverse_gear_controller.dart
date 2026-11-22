import 'dart:async';

import 'package:carnine_frontend/features/dashboard/data/reverse_gear_source.dart';
import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Brings the camera page while the reverse gear is in, and the page from
/// before back when it is out again (#191).
///
/// - In: remembers the page that is open and shows the camera; with the
///   camera already open there is nothing to go back to.
/// - Out: back to the remembered page at once, unless the driver chose
///   another page in the meantime - then that one stays.
/// - Unknown: switches nothing, not even back; the camera page says that the
///   signal is missing.
/// - No source configured: does nothing at all.
class ReverseGearController extends ChangeNotifier {
  ReverseGearController({
    required this._currentPage,
    required this._showCamera,
    required this._showPage,
    ReverseGearSource? source,
    Logger? logger,
  }) : _source = source ?? GrpcReverseGearSource(),
       _logger = logger ?? Logger('ReverseGearController');

  final DashboardDestination Function() _currentPage;

  /// Shows the camera without saving it as the last page.
  final VoidCallback _showCamera;

  /// Shows [DashboardDestination] again, also without saving it.
  final ValueChanged<DashboardDestination> _showPage;
  final ReverseGearSource _source;
  final Logger _logger;
  StreamSubscription<ReverseGearStatus>? _subscription;
  ReverseGearStatus _status = ReverseGearStatus.none;

  /// The page the gear took the driver from, while it brought the camera.
  DashboardDestination? _returnTo;

  ReverseGearStatus get status => _status;

  /// The gear is in: the dashboard does not go back to the map on its own
  /// in the trade fair mode (#128).
  bool get isEngaged =>
      _status.configured && _status.gear == ReverseGear.engaged;

  /// A source is set up, but the gear cannot be told: the hint on the
  /// camera page.
  bool get isSignalMissing =>
      _status.configured && _status.gear == ReverseGear.unknown;

  /// [isSignalMissing] for the camera page, which knows nothing else of the
  /// gear.
  ValueListenable<bool> get signalMissing => _signalMissing;
  final ValueNotifier<bool> _signalMissing = ValueNotifier<bool>(false);

  void start() {
    _subscription ??= _source.statuses.listen(_onStatus);
  }

  void _onStatus(ReverseGearStatus status) {
    final wasEngaged = isEngaged;
    _status = status;
    if (status.configured) {
      switch (status.gear) {
        case ReverseGear.engaged when !wasEngaged:
          _engage();
        case ReverseGear.out:
          _release();
        case ReverseGear.engaged || ReverseGear.unknown:
          break;
      }
    }
    _signalMissing.value = isSignalMissing;
    notifyListeners();
  }

  void _engage() {
    final page = _currentPage();
    _logger.info('Reverse gear in, showing the camera (from ${page.name})');
    if (page == DashboardDestination.camera) {
      _returnTo = null;
      return;
    }
    _returnTo = page;
    _showCamera();
  }

  void _release() {
    final page = _returnTo;
    _returnTo = null;
    if (page == null) {
      return;
    }
    if (_currentPage() != DashboardDestination.camera) {
      _logger.info('Reverse gear out, the driver chose another page');
      return;
    }
    _logger.info('Reverse gear out, back to ${page.name}');
    _showPage(page);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_source.dispose());
    _signalMissing.dispose();
    super.dispose();
  }
}
