import 'package:carnine_frontend/data/services/carnine_grpc_service.dart';
import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

/// Presentation controller for dashboard state and user actions.
///
/// The controller keeps network calls out of widgets while staying lightweight
/// with Flutter's native `ChangeNotifier` state mechanism.
class DashboardController extends ChangeNotifier {
  DashboardController({
    CarnineGrpcService? grpcService,
    Logger? logger,
  })  : _grpcService = grpcService ?? CarnineGrpcService(),
        _logger = logger ?? Logger('DashboardController');

  static const List<DashboardNavItem> navItems = <DashboardNavItem>[
    DashboardNavItem(
      destination: DashboardDestination.home,
      icon: Icons.home,
      labelKey: AppTextKey.navHome,
      semanticLabelKey: AppTextKey.navHomeSemantic,
    ),
    DashboardNavItem(
      destination: DashboardDestination.maps,
      icon: Icons.map,
      labelKey: AppTextKey.navMaps,
      semanticLabelKey: AppTextKey.navMapsSemantic,
    ),
    DashboardNavItem(
      destination: DashboardDestination.media,
      icon: Icons.play_circle,
      labelKey: AppTextKey.navMedia,
      semanticLabelKey: AppTextKey.navMediaSemantic,
    ),
    DashboardNavItem(
      destination: DashboardDestination.climate,
      icon: Icons.thermostat,
      labelKey: AppTextKey.navClimate,
      semanticLabelKey: AppTextKey.navClimateSemantic,
    ),
    DashboardNavItem(
      destination: DashboardDestination.controls,
      icon: Icons.lightbulb_outline,
      labelKey: AppTextKey.navControls,
      semanticLabelKey: AppTextKey.navControlsSemantic,
    ),
    DashboardNavItem(
      destination: DashboardDestination.settings,
      icon: Icons.settings,
      labelKey: AppTextKey.navSettings,
      semanticLabelKey: AppTextKey.navSettingsSemantic,
    ),
  ];

  final CarnineGrpcService _grpcService;
  final Logger _logger;

  int _selectedIndex = 0;
  DashboardGrpcStatus _grpcStatus = DashboardGrpcStatus.notConnected;
  int _receivedCanDataCount = 0;
  String _grpcErrorMessage = '';
  List<CanData> _canData = const <CanData>[];
  bool _isGrpcLoading = false;

  int get selectedIndex => _selectedIndex;
  DashboardGrpcStatus get grpcStatus => _grpcStatus;
  int get receivedCanDataCount => _receivedCanDataCount;
  String get grpcErrorMessage => _grpcErrorMessage;
  List<CanData> get canData => _canData;
  bool get isGrpcLoading => _isGrpcLoading;
  DashboardNavItem get selectedItem => navItems[_selectedIndex];

  /// Selects the active dashboard section from the side menu.
  void selectItem(int index) {
    if (index == _selectedIndex || index < 0 || index >= navItems.length) {
      return;
    }

    final previousItem = selectedItem;
    final nextItem = navItems[index];
    _logger.info(
      'Switching dashboard page from ${previousItem.destination.name} '
      'to ${nextItem.destination.name}',
    );

    _selectedIndex = index;
    notifyListeners();
  }

  /// Exercises the generated gRPC client and exposes the result to the UI.
  Future<void> testGrpc() async {
    if (_isGrpcLoading) {
      return;
    }

    _markGrpcLoading();

    try {
      final data = await _grpcService.fetchEngineTemperature();
      _canData = data;
      _receivedCanDataCount = data.length;
      _grpcErrorMessage = '';
      _grpcStatus = DashboardGrpcStatus.connected;
    } catch (error, stackTrace) {
      _logger.severe('Dashboard gRPC test failed', error, stackTrace);
      _grpcErrorMessage = error.toString();
      _grpcStatus = DashboardGrpcStatus.error;
    } finally {
      _isGrpcLoading = false;
      notifyListeners();
    }
  }

  void _markGrpcLoading() {
    _logger.info('Triggering gRPC test request');
    _isGrpcLoading = true;
    _grpcStatus = DashboardGrpcStatus.connecting;
    notifyListeners();
  }
}

enum DashboardGrpcStatus {
  notConnected,
  connecting,
  connected,
  error,
}
