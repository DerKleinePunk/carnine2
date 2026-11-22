import 'dart:io';

import 'package:carnine_frontend/core/logging/app_logging.dart';
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

  /// Exit code that asks the supervising systemd unit to start the frontend
  /// again (`RestartForceExitStatus=` in carnine-frontend.service).
  static const int restartExitCode = 75;

  /// Set by a test to take the device's way (`CARNINE_EMBEDDED`) or not.
  @visibleForTesting
  static bool? embeddedOverride;

  static bool get _isEmbedded =>
      embeddedOverride ?? Platform.environment.containsKey('CARNINE_EMBEDDED');

  static bool get _usesWindowManager {
    return !_isEmbedded &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  }

  static Future<void> _showAndFocus() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Ends the process; a test puts its own in, the real exit would end the
  /// test run.
  @visibleForTesting
  static void Function(int code) exitProcess = exit;

  /// Writes [reason] and waits until it is in frontend.log before the
  /// process ends: an exit straight after logging lost the line, and a
  /// wanted restart looked like a crash in the log (#173).
  static Future<void> _exitLogged(int code, String reason) async {
    _logger.info(reason);
    await AppLogging.shutdown();
    exitProcess(code);
  }

  /// "Beenden" in the options, after the password.
  static Future<void> exitApplication() =>
      _exitLogged(0, 'Exit requested by user');

  /// Restarts only this frontend process - not a system reboot.
  ///
  /// On the target the unit restarts it: a detached copy would not survive,
  /// because systemd stops the whole control group once the main process
  /// exits, and the embedder's own arguments are not visible to Dart. On a
  /// dev run a detached copy of the running executable takes over.
  static Future<void> restartApplication() async {
    if (_isEmbedded) {
      await _exitLogged(
        restartExitCode,
        'Restart requested by user, exiting with $restartExitCode so systemd '
        'restarts the frontend',
      );
      return;
    }

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

    await _exitLogged(0, 'Restart requested by user, a new process takes over');
  }
}
