import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop window setup for the fixed 1024x600 car display target.
abstract final class AppWindow {
  const AppWindow._();

  static final Logger _logger = Logger('AppWindow');

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
    return !Platform.environment.containsKey('CARNINE_FLUTTER_PI') &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  }

  static Future<void> _showAndFocus() async {
    await windowManager.show();
    await windowManager.focus();
  }

  static void exitApplication() {
    exit(0);
  }

  /// Restarts only this frontend process - not a system reboot. Spawns a
  /// detached copy of the running executable before exiting this one, so it
  /// works the same whether systemd (`Restart=on-failure`, which a clean
  /// exit code would not trigger) or a plain dev run is supervising it.
  static Future<void> restartApplication() async {
    try {
      await Process.start(
        Platform.resolvedExecutable,
        Platform.executableArguments,
        mode: ProcessStartMode.detached,
      );
    } catch (error, stackTrace) {
      // Keep running rather than exit into a dead end - a failed restart
      // should leave the current instance usable, not close the app with
      // nothing left to replace it.
      _logger.severe(
        'Failed to spawn a replacement process for restart',
        error,
        stackTrace,
      );
      return;
    }

    exit(0);
  }
}
