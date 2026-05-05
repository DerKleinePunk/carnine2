import 'package:carnine_frontend/app/carnine_app.dart';
import 'package:carnine_frontend/core/logging/app_logging.dart';
import 'package:carnine_frontend/core/platform/app_window.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppWindow.ensureConfigured();
  await AppLogging.initialize();

  AppLogging.frontend.info('Frontend app started');
  runApp(const CarnineApp());
}
