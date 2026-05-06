import 'package:carnine_frontend/data/services/carnine_grpc_service.dart';
import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart';
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
      label: 'Home',
      icon: Icons.home,
      semanticLabel: 'Home dashboard',
    ),
    DashboardNavItem(
      label: 'Maps',
      icon: Icons.map,
      semanticLabel: 'Maps',
    ),
    DashboardNavItem(
      label: 'Media',
      icon: Icons.play_circle,
      semanticLabel: 'Media player',
    ),
    DashboardNavItem(
      label: 'Climate',
      icon: Icons.thermostat,
      semanticLabel: 'Climate controls',
    ),
    DashboardNavItem(
      label: 'Controls',
      icon: Icons.lightbulb_outline,
      semanticLabel: 'Auxiliary controls',
    ),
    DashboardNavItem(
      label: 'Settings',
      icon: Icons.settings,
      semanticLabel: 'Settings',
    ),
  ];

  final CarnineGrpcService _grpcService;
  final Logger _logger;

  int _selectedIndex = 0;
  String _grpcStatus = 'Not connected';
  List<CanData> _canData = const <CanData>[];
  bool _isGrpcLoading = false;

  int get selectedIndex => _selectedIndex;
  String get grpcStatus => _grpcStatus;
  List<CanData> get canData => _canData;
  bool get isGrpcLoading => _isGrpcLoading;
  DashboardNavItem get selectedItem => navItems[_selectedIndex];

  /// Selects the active dashboard section from the side menu.
  void selectItem(int index) {
    if (index == _selectedIndex || index < 0 || index >= navItems.length) {
      return;
    }

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
      _grpcStatus = 'Connected - Received ${data.length} data points';
    } catch (error, stackTrace) {
      _logger.severe('Dashboard gRPC test failed', error, stackTrace);
      _grpcStatus = 'Error: $error';
    } finally {
      _isGrpcLoading = false;
      notifyListeners();
    }
  }

  void _markGrpcLoading() {
    _logger.info('Triggering gRPC test request');
    _isGrpcLoading = true;
    _grpcStatus = 'Connecting...';
    notifyListeners();
  }
}
