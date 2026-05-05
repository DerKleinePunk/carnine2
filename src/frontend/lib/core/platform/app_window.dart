import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop window setup for the fixed 1024x600 car display target.
abstract final class AppWindow {
  const AppWindow._();

  static const Size displaySize = Size(1024, 600);

  static const WindowOptions _windowOptions = WindowOptions(
    size: displaySize,
    minimumSize: displaySize,
    maximumSize: displaySize,
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  /// Applies desktop window constraints when Flutter runs outside mobile/web.
  static Future<void> ensureConfigured() async {
    if (!_usesWindowManager) {
      return;
    }

    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(_windowOptions, _showAndFocus);
  }

  static bool get _usesWindowManager {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  static Future<void> _showAndFocus() async {
    await windowManager.show();
    await windowManager.focus();
  }
}
