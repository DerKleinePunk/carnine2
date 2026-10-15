import 'package:carnine_frontend/features/camera/data/camera_settings_store.dart';
import 'package:carnine_frontend/features/camera/presentation/camera_content.dart';
import 'package:carnine_frontend/features/controls/data/controls_repository.dart';
import 'package:carnine_frontend/features/controls/presentation/controls_content.dart';
import 'package:carnine_frontend/features/dashboard/presentation/cpu_temperature_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
import 'package:carnine_frontend/features/dashboard/presentation/power_supply_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/thermal_warning_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/home/home_content.dart';
import 'package:carnine_frontend/features/maps/presentation/maps_content.dart';
import 'package:carnine_frontend/features/maps/presentation/maps_controller.dart';
import 'package:carnine_frontend/features/media/presentation/media_content.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/features/maps/presentation/map_follow_zoom_controller.dart';
import 'package:carnine_frontend/features/settings/data/announcement_settings_store.dart';
import 'package:carnine_frontend/features/settings/data/display_brightness_store.dart';
import 'package:carnine_frontend/features/settings/data/exit_password_store.dart';
import 'package:carnine_frontend/features/settings/presentation/settings_content.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:flutter/material.dart';

/// Dashboard body area that shows the active section.
class DashboardContent extends StatelessWidget {
  const DashboardContent({
    required this.selectedItem,
    required this.languageController,
    required this.mediaController,
    required this.mapsController,
    required this.powerSupplyController,
    required this.thermalWarningController,
    required this.cpuTemperatureController,
    required this.onSelectDestination,
    this.cameraSettingsStore,
    this.exitPasswordStore,
    this.announcementSettingsStore,
    this.followZoomController,
    this.displayBrightnessStore,
    this.cameraSourceFactory,
    this.onShowCamera,
    this.controlsRepository,
    super.key,
  });

  final DashboardNavItem selectedItem;
  final AppLanguageController languageController;
  final MediaController mediaController;
  final MapsController mapsController;
  final PowerSupplyController powerSupplyController;
  final ThermalWarningController thermalWarningController;
  final CpuTemperatureController cpuTemperatureController;

  /// Opens another page, like a tap in the side menu - the tiles of the start
  /// page lead to the map and to the media.
  final ValueChanged<DashboardDestination> onSelectDestination;
  final CameraSettingsStore? cameraSettingsStore;
  final ExitPasswordStore? exitPasswordStore;
  final AnnouncementSettingsStore? announcementSettingsStore;

  /// The zoom of following the car; shared by the map and the options.
  final MapFollowZoomController? followZoomController;
  final DisplayBrightnessStore? displayBrightnessStore;
  final GrabberSourceFactory? cameraSourceFactory;

  /// Selects the Kamera page - from the camera settings, to look at a change.
  final VoidCallback? onShowCamera;

  /// Where the Technik page gets its controls from; tests leave it out.
  final ControlsRepository? controlsRepository;

  @override
  Widget build(BuildContext context) {
    if (selectedItem.destination == DashboardDestination.settings) {
      return SettingsContent(
        languageController: languageController,
        cameraSettingsStore: cameraSettingsStore,
        exitPasswordStore: exitPasswordStore,
        announcementSettingsStore: announcementSettingsStore,
        followZoomController: followZoomController,
        displayBrightnessStore: displayBrightnessStore,
        onShowCamera: onShowCamera,
      );
    }

    if (selectedItem.destination == DashboardDestination.media) {
      return MediaContent(controller: mediaController);
    }

    if (selectedItem.destination == DashboardDestination.maps) {
      return MapsContent(
        controller: mapsController,
        followZoom: followZoomController,
      );
    }

    // Built only while the page is shown: leaving it closes the stream.
    if (selectedItem.destination == DashboardDestination.controls) {
      return ControlsContent(repository: controlsRepository);
    }

    // Built only while the page is shown: leaving it closes the camera.
    if (selectedItem.destination == DashboardDestination.camera) {
      return CameraContent(
        settingsStore: cameraSettingsStore,
        sourceFactory: cameraSourceFactory,
      );
    }

    return HomeContent(
      mapsController: mapsController,
      mediaController: mediaController,
      powerSupplyController: powerSupplyController,
      thermalWarningController: thermalWarningController,
      cpuTemperatureController: cpuTemperatureController,
      controlsRepository: controlsRepository,
      onOpen: onSelectDestination,
    );
  }
}
