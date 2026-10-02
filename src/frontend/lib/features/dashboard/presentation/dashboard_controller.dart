import 'dart:async';

import 'package:carnine_frontend/data/services/carnine_grpc_service.dart';
import 'package:carnine_frontend/features/dashboard/data/ui_state_store.dart';
import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';

/// Presentation controller for dashboard state and user actions.
///
/// The controller keeps network calls out of widgets while staying lightweight
/// with Flutter's native `ChangeNotifier` state mechanism.
class DashboardController extends ChangeNotifier {
  DashboardController({
    CarnineGrpcService? grpcService,
    this._uiStateStore,
    Logger? logger,
  }) : _grpcService = grpcService ?? CarnineGrpcService(),
       _logger = logger ?? Logger('DashboardController');

  /// Waits this long after a switch before saving the page, so tapping
  /// through the menu does not call the backend for every page.
  static const Duration pageSaveDelay = Duration(seconds: 2);

  /// Pauses between attempts to read the saved page while the backend is not
  /// up yet; the last one repeats. The frontend can start before the backend,
  /// e.g. when the car is switched on (#52).
  static const List<Duration> restoreRetryDelays = <Duration>[
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  /// Gives up restoring after this long without a backend.
  static const Duration restoreGiveUpAfter = Duration(minutes: 2);

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
      destination: DashboardDestination.camera,
      icon: Icons.videocam,
      labelKey: AppTextKey.navCamera,
      semanticLabelKey: AppTextKey.navCameraSemantic,
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
  final UiStateStore? _uiStateStore;
  final Logger _logger;
  Timer? _pageSaveTimer;
  bool _userSelectedPage = false;
  bool _disposed = false;

  int _selectedIndex = 0;
  DashboardGrpcStatus _grpcStatus = DashboardGrpcStatus.notConnected;
  int _receivedCanDataCount = 0;
  List<CanData> _canData = const <CanData>[];
  bool _isGrpcLoading = false;

  int get selectedIndex => _selectedIndex;
  DashboardGrpcStatus get grpcStatus => _grpcStatus;
  int get receivedCanDataCount => _receivedCanDataCount;
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
    _userSelectedPage = true;
    _schedulePageSave(nextItem.destination);
    notifyListeners();
  }

  /// Selects the section for [destination], like a tap in the side menu
  /// (the camera settings jump to the camera page this way).
  void selectDestination(DashboardDestination destination) {
    selectItem(navItems.indexWhere((item) => item.destination == destination));
  }

  /// Opens the page saved last, unless the user picked one in the meantime.
  ///
  /// While the backend is unreachable it tries again with growing pauses
  /// until it answers, the user picks a page or [restoreGiveUpAfter] passes.
  Future<void> restoreLastPage() async {
    final store = _uiStateStore;
    if (store == null) {
      return;
    }
    var waited = Duration.zero;
    for (var attempt = 0; ; attempt++) {
      try {
        final name = await store.loadLastPage();
        _applyRestoredPage(name);
        return;
      } on GrpcError catch (error, stackTrace) {
        if (error.code != StatusCode.unavailable ||
            waited >= restoreGiveUpAfter) {
          _logger.warning('Could not restore the last page', error, stackTrace);
          return;
        }
        if (attempt == 0) {
          _logger.info('Backend not reachable yet, retrying the last page');
        }
      } catch (error, stackTrace) {
        _logger.warning('Could not restore the last page', error, stackTrace);
        return;
      }
      final delay =
          restoreRetryDelays[attempt < restoreRetryDelays.length
              ? attempt
              : restoreRetryDelays.length - 1];
      waited += delay;
      await Future<void>.delayed(delay);
      if (_disposed || _userSelectedPage) {
        return;
      }
    }
  }

  void _applyRestoredPage(String savedName) {
    // The camera page was the climate page until October 2026.
    final name = savedName == 'climate'
        ? DashboardDestination.camera.name
        : savedName;
    final index = navItems.indexWhere(
      (item) =>
          item.destination.name == name && _isRestorable(item.destination),
    );
    if (_disposed ||
        _userSelectedPage ||
        index < 0 ||
        index == _selectedIndex) {
      return;
    }
    _logger.info('Restoring dashboard page $name');
    _selectedIndex = index;
    notifyListeners();
  }

  /// Settings are a detour, not a place to come back to after a restart.
  static bool _isRestorable(DashboardDestination destination) =>
      destination != DashboardDestination.settings;

  void _schedulePageSave(DashboardDestination destination) {
    if (_uiStateStore == null || !_isRestorable(destination)) {
      return;
    }
    _pageSaveTimer?.cancel();
    _pageSaveTimer = Timer(pageSaveDelay, () => _savePage(destination));
  }

  Future<void> _savePage(DashboardDestination destination) async {
    _pageSaveTimer = null;
    try {
      await _uiStateStore?.saveLastPage(destination.name);
      _logger.info('Saved dashboard page ${destination.name}');
    } catch (error, stackTrace) {
      _logger.warning('Could not save the page', error, stackTrace);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_pageSaveTimer?.isActive ?? false) {
      _pageSaveTimer?.cancel();
      unawaited(_savePage(selectedItem.destination));
    }
    super.dispose();
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
      _grpcStatus = DashboardGrpcStatus.connected;
    } catch (error, stackTrace) {
      _logger.severe('Dashboard gRPC test failed', error, stackTrace);
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

enum DashboardGrpcStatus { notConnected, connecting, connected, error }
