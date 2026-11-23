import 'dart:async';
import 'dart:io';

import 'package:carnine_frontend/app/carnine_app.dart';
import 'package:carnine_frontend/features/controls/data/controls_repository.dart';
import 'package:carnine_frontend/app/ui_readiness.dart';
import 'package:carnine_frontend/app/ui_ready_detector.dart';
import 'package:carnine_frontend/core/app_version.dart';
import 'package:carnine_frontend/core/logging/app_logging.dart';
import 'package:carnine_frontend/core/platform/app_window.dart';
import 'package:carnine_frontend/data/services/carnine_grpc_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:logging/logging.dart';

// build_pi.sh stamps the version into the two defaults below, so they stay
// here, in main.dart, and are handed to [AppVersion] at start.
const _carnineVersion = String.fromEnvironment(
  'CARNINE_VERSION',
  defaultValue: 'unknown',
);
const _carnineBuildVersion = String.fromEnvironment(
  'CARNINE_BUILD_VERSION',
  defaultValue: _carnineVersion,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppWindow.ensureConfigured();
  await AppLogging.initialize();

  AppVersion.initialize(version: _carnineVersion, build: _carnineBuildVersion);
  AppLogging.frontend.info(
    'Frontend app started; version=$_carnineVersion build=$_carnineBuildVersion',
  );
  final backend = CarnineGrpcService();
  runApp(
    CarnineApp(
      uiStateStore: backend,
      cameraSettingsStore: backend,
      exitPasswordStore: backend,
      announcementSettingsStore: backend,
      mapFollowZoomStore: backend,
      trafficSettingStore: backend,
      displayBrightnessStore: backend,
      installValuesStore: backend,
      controlsRepository: GrpcControlsRepository(),
    ),
  );

  // Readiness is reported with the first frame on screen (#37): systemd's
  // READY, the end of the boot logo and the amplifier relay wait for it.
  final binding = SchedulerBinding.instance;
  UiReadyDetector(
    addTimingsCallback: binding.addTimingsCallback,
    removeTimingsCallback: binding.removeTimingsCallback,
    onReady: () => unawaited(_reportUiReady()),
  ).start();
}

Future<void> _reportUiReady() async {
  await UiReadinessReporter(
    reportToBackend: CarnineGrpcService().reportUiReady,
    notifySystemd: _notifySystemdReady,
  ).report();
}

Future<void> _notifySystemdReady() async {
  if (Platform.environment.containsKey('NOTIFY_SOCKET')) {
    await Process.run('/usr/bin/systemd-notify', [
      '--ready',
      '--status=Carnine UI ready',
    ]);
  } else {
    Logger(
      'CarnineGrpcService',
    ).warning('UI readiness reported to backend, but NOTIFY_SOCKET is not set');
  }
}
