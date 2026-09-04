import 'dart:async';
import 'dart:io';

import 'package:carnine_frontend/app/carnine_app.dart';
import 'package:carnine_frontend/core/logging/app_logging.dart';
import 'package:carnine_frontend/core/platform/app_window.dart';
import 'package:carnine_frontend/data/services/carnine_grpc_service.dart';
import 'package:flutter/material.dart';

const _carnineVersion = String.fromEnvironment(
  'CARNINE_VERSION',
  defaultValue: 'unknown',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppWindow.ensureConfigured();
  await AppLogging.initialize();

  AppLogging.frontend.info('Frontend app started; version=$_carnineVersion');
  runApp(const CarnineApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_reportUiReady());
  });
}

Future<void> _reportUiReady() async {
  try {
    await CarnineGrpcService().reportUiReady();
    if (Platform.environment.containsKey('NOTIFY_SOCKET')) {
      await Process.run('/usr/bin/systemd-notify', [
        '--ready',
        '--status=Carnine UI ready',
      ]);
    }
  } catch (error, stackTrace) {
    AppLogging.frontend.severe(
      'UI readiness handshake failed',
      error,
      stackTrace,
    );
  }
}
