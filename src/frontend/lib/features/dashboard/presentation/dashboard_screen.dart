import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_scope.dart';
import 'package:carnine_frontend/features/camera/data/camera_settings_store.dart';
import 'package:carnine_frontend/features/camera/presentation/camera_content.dart';
import 'package:carnine_frontend/features/controls/data/controls_repository.dart';
import 'dart:async';

import 'package:carnine_frontend/features/dashboard/data/ui_state_store.dart';
import 'package:carnine_frontend/features/maps/presentation/maps_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/idle_return.dart';
import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
import 'package:carnine_frontend/features/dashboard/presentation/power_supply_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/thermal_warning_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/carnine_top_bar.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/dashboard_content.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/side_menu.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/thermal_warning_overlay.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/features/maps/data/map_follow_zoom_store.dart';
import 'package:carnine_frontend/features/maps/presentation/map_follow_zoom_controller.dart';
import 'package:carnine_frontend/features/settings/data/announcement_settings_store.dart';
import 'package:carnine_frontend/features/settings/data/display_brightness_store.dart';
import 'package:carnine_frontend/features/settings/data/exit_password_store.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Main dashboard shell for the fixed car display.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.languageController,
    this.controller,
    this.mediaController,
    this.mapsController,
    this.powerSupplyController,
    this.thermalWarningController,
    this.uiStateStore,
    this.cameraSettingsStore,
    this.exitPasswordStore,
    this.announcementSettingsStore,
    this.mapFollowZoomStore,
    this.displayBrightnessStore,
    this.controlsRepository,
    this.cameraSourceFactory,
    this.idleReturnAfter = const Duration(seconds: 60),
    super.key,
  });

  final AppLanguageController languageController;
  final DashboardController? controller;
  final MediaController? mediaController;
  final MapsController? mapsController;
  final PowerSupplyController? powerSupplyController;
  final ThermalWarningController? thermalWarningController;

  /// Where the page shown last is kept; without it the dashboard always
  /// starts on the first page. Ignored when [controller] is given.
  final UiStateStore? uiStateStore;

  /// Where the camera page gets its settings; without it the defaults.
  final CameraSettingsStore? cameraSettingsStore;

  /// Where the password for "Beenden" is checked and changed.
  final ExitPasswordStore? exitPasswordStore;

  /// Where the options keep the settings of the spoken announcements.
  final AnnouncementSettingsStore? announcementSettingsStore;

  /// Where the zoom of following the car is kept.
  final MapFollowZoomStore? mapFollowZoomStore;

  /// Where the display brightness is read and set.
  final DisplayBrightnessStore? displayBrightnessStore;

  /// Where the Technik page gets its controls from; tests leave it out.
  final ControlsRepository? controlsRepository;

  /// The camera page's picture source; the native grabber unless a test
  /// gives one.
  final GrabberSourceFactory? cameraSourceFactory;

  /// Trade fair mode: how long nobody touches the screen before it returns to
  /// the map (#128).
  final Duration idleReturnAfter;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardController _controller =
      widget.controller ??
      DashboardController(uiStateStore: widget.uiStateStore);

  // Owned here, not by MediaContent, so the queue and playback state survive
  // switching to another sidebar section and back - MediaContent would
  // otherwise be torn down and rebuilt on every visit, losing everything but
  // the currently playing path (the only thing the backend re-reports).
  late final MediaController _mediaController =
      widget.mediaController ?? MediaController();

  bool get _ownsController => widget.controller == null;
  // Same reasoning as the media controller: route, destination and the
  // position stream must survive switching to another section and back.
  late final MapsController _mapsController =
      widget.mapsController ??
      MapsController(
        // Instructions in the language set in the settings, read per route.
        language: () => widget.languageController.locale.languageCode,
      );

  // What the car power supply reports, for the top bar and the notice.
  late final PowerSupplyController _powerSupplyController =
      widget.powerSupplyController ?? PowerSupplyController();

  // The overheating warning, over every page (#70).
  late final ThermalWarningController _thermalWarningController =
      widget.thermalWarningController ?? ThermalWarningController();

  bool get _ownsMediaController => widget.mediaController == null;
  bool get _ownsMapsController => widget.mapsController == null;
  bool get _ownsPowerSupplyController => widget.powerSupplyController == null;
  bool get _ownsThermalWarningController =>
      widget.thermalWarningController == null;

  DashboardGrpcStatus _lastHandledGrpcStatus = DashboardGrpcStatus.notConnected;

  // The zoom of following the car (#131): the map page and the options use it.
  late final MapFollowZoomController _followZoomController =
      MapFollowZoomController(store: widget.mapFollowZoomStore);

  // Trade fair mode (#128): back to the map after a minute without a touch.
  late final IdleReturn _idleReturn = IdleReturn(
    after: widget.idleReturnAfter,
    isEnabled: () => _mapsController.demoMode,
    onIdle: _returnToMap,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChange);
    _mapsController.addListener(_idleReturn.sync);
    unawaited(_followZoomController.load());
    // Every touch anywhere counts - also on the keyboard and in dialogs,
    // which are outside of this screen's widget tree.
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointer);
    unawaited(_controller.restoreLastPage());
    _powerSupplyController.start();
    _thermalWarningController.start();
    // At once, not only when the media page opens first: the notice about a
    // missing audio output belongs on every page (#56).
    unawaited(_mediaController.start());
  }

  @override
  void dispose() {
    _idleReturn.dispose();
    _followZoomController.dispose();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handlePointer);
    _mapsController.removeListener(_idleReturn.sync);
    _controller.removeListener(_handleControllerChange);
    if (_ownsController) {
      _controller.dispose();
    }
    if (_ownsMediaController) {
      _mediaController.dispose();
    }
    if (_ownsMapsController) {
      _mapsController.dispose();
    }
    if (_ownsPowerSupplyController) {
      _powerSupplyController.dispose();
    }
    if (_ownsThermalWarningController) {
      _thermalWarningController.dispose();
    }

    super.dispose();
  }

  void _handlePointer(PointerEvent event) {
    if (event is PointerDownEvent ||
        event is PointerMoveEvent ||
        event is PointerUpEvent) {
      _idleReturn.touch();
    }
  }

  void _returnToMap() {
    if (!mounted ||
        !_mapsController.demoMode ||
        _controller.selectedItem.destination == DashboardDestination.maps) {
      // On the map there is nothing to do.
      return;
    }
    if (_isInInput()) {
      // Someone is typing or choosing: wait another minute.
      _idleReturn.restart();
      return;
    }
    _controller.selectDestination(DashboardDestination.maps);
  }

  /// The keyboard, a dialog or a playlist flow is open: leaving would throw
  /// away what someone is in the middle of.
  bool _isInInput() {
    if (OnScreenKeyboardScope.maybeOf(context)?.isOpen ?? false) {
      return true;
    }
    // A dialog is a route above the dashboard.
    if (Navigator.maybeOf(context)?.canPop() ?? false) {
      return true;
    }
    return _controller.selectedItem.destination == DashboardDestination.media &&
        _mediaController.isEditingPlaylist;
  }

  /// Surfaces backend connection failures as a dialog exactly once per
  /// occurrence, instead of leaking the raw exception into inline UI text.
  void _handleControllerChange() {
    final status = _controller.grpcStatus;
    if (status == DashboardGrpcStatus.error &&
        _lastHandledGrpcStatus != DashboardGrpcStatus.error) {
      _showGrpcErrorDialog();
    }

    _lastHandledGrpcStatus = status;
  }

  Future<void> _showGrpcErrorDialog() async {
    if (!mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context);

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.text(AppTextKey.grpcConnectionErrorTitle)),
        content: Text(l10n.text(AppTextKey.grpcConnectionErrorMessage)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.text(AppTextKey.close)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Scaffold(
          body: Stack(
            children: [
              _buildPages(),
              ThermalWarningOverlay(controller: _thermalWarningController),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPages() {
    return Row(
      children: [
        SideMenu(
          items: DashboardController.navItems,
          selectedIndex: _controller.selectedIndex,
          onItemSelected: _controller.selectItem,
        ),
        Expanded(
          child: Column(
            children: [
              ListenableBuilder(
                listenable: _powerSupplyController,
                builder: (context, _) {
                  final status = _powerSupplyController.status;
                  return Column(
                    children: [
                      CarnineTopBar(powerSupply: status),
                      PowerSupplyNotice(status: status),
                      ListenableBuilder(
                        listenable: _mediaController.audio,
                        builder: (context, _) => AudioOutputNotice(
                          available: _mediaController.audio.outputAvailable,
                        ),
                      ),
                    ],
                  );
                },
              ),
              Expanded(
                child: DashboardContent(
                  selectedItem: _controller.selectedItem,
                  grpcStatus: _controller.grpcStatus,
                  receivedCanDataCount: _controller.receivedCanDataCount,
                  canData: _controller.canData,
                  isGrpcLoading: _controller.isGrpcLoading,
                  onTestGrpc: _controller.testGrpc,
                  languageController: widget.languageController,
                  mediaController: _mediaController,
                  mapsController: _mapsController,
                  cameraSettingsStore: widget.cameraSettingsStore,
                  exitPasswordStore: widget.exitPasswordStore,
                  announcementSettingsStore: widget.announcementSettingsStore,
                  followZoomController: _followZoomController,
                  displayBrightnessStore: widget.displayBrightnessStore,
                  cameraSourceFactory: widget.cameraSourceFactory,
                  onShowCamera: () => _controller.selectDestination(
                    DashboardDestination.camera,
                  ),
                  controlsRepository: widget.controlsRepository,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
