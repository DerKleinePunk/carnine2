import 'dart:async';
import 'dart:io';

import 'package:carnine_frontend/app/carnine_app.dart';
import 'package:carnine_frontend/core/logging/app_logging.dart';
import 'package:carnine_frontend/core/platform/app_window.dart';
import 'package:carnine_frontend/data/services/carnine_grpc_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:logging/logging.dart';

// The embedder (flutter-pi) can silently drop a frame's DRM commit (e.g. while
// the display is still owned by Plymouth) without surfacing the failure to
// the engine, and it does not retry on its own. A single addPostFrameCallback
// only proves the engine rasterized a frame, not that it reached the screen.
// Forcing several frames and requiring multiple timing reports gives the
// commit path repeated chances to succeed before we tell systemd/Plymouth
// the UI is ready. _uiReadyMaxWait is a safety net so this can never stall
// past carnine-frontend.service's TimeoutStartSec.
const _uiReadyMinFrames = 5;
const _uiReadyFrameForceInterval = Duration(milliseconds: 100);
const _uiReadyMaxWait = Duration(seconds: 5);

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

  AppLogging.frontend.info(
    'Frontend app started; version=$_carnineVersion build=$_carnineBuildVersion',
  );
  runApp(CarnineApp(uiStateStore: CarnineGrpcService()));

  _scheduleUiReadyDetection();
}

void _scheduleUiReadyDetection() {
  var framesSeen = 0;
  var finished = false;
  Timer? forceFrameTimer;
  Timer? maxWaitTimer;
  late void Function(List<FrameTiming>) onTimings;

  void finish() {
    if (finished) return;
    finished = true;
    SchedulerBinding.instance.removeTimingsCallback(onTimings);
    forceFrameTimer?.cancel();
    maxWaitTimer?.cancel();
    unawaited(_reportUiReady());
  }

  onTimings = (timings) {
    framesSeen += timings.length;
    if (framesSeen >= _uiReadyMinFrames) {
      finish();
    }
  };
  SchedulerBinding.instance.addTimingsCallback(onTimings);

  forceFrameTimer = Timer.periodic(_uiReadyFrameForceInterval, (_) {
    SchedulerBinding.instance.scheduleFrame();
  });
  maxWaitTimer = Timer(_uiReadyMaxWait, finish);
}

Future<void> _reportUiReady() async {
  try {
    await CarnineGrpcService().reportUiReady();
    Logger('CarnineGrpcService').info('UI readiness reported to backend');
    if (Platform.environment.containsKey('NOTIFY_SOCKET')) {
      await Process.run('/usr/bin/systemd-notify', [
        '--ready',
        '--status=Carnine UI ready',
      ]);
    } else {
      Logger('CarnineGrpcService').warning('UI readiness reported to backend, but NOTIFY_SOCKET is not set');
    }
  } catch (error, stackTrace) {
    AppLogging.frontend.severe(
      'UI readiness handshake failed',
      error,
      stackTrace,
    );
  }
}
