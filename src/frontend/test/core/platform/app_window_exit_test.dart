import 'dart:io';

import 'package:carnine_frontend/core/logging/app_logging.dart';
import 'package:carnine_frontend/core/platform/app_window.dart';
import 'package:flutter_test/flutter_test.dart';

/// Restart and exit write their line into frontend.log before the process
/// ends (#173). The real exit is replaced, so the test run goes on.
void main() {
  late Directory directory;
  late File log;
  late List<int> exitCodes;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('carnine-exit-log');
    log = File('${directory.path}/frontend.log');
    await AppLogging.initialize(logPath: log.path);
    exitCodes = [];
    AppWindow.exitProcess = exitCodes.add;
  });

  tearDown(() async {
    AppWindow.exitProcess = exit;
    AppWindow.embeddedOverride = null;
    await AppLogging.shutdown();
    await directory.delete(recursive: true);
  });

  test('a restart on the device writes its line, then exits with 75', () async {
    AppWindow.embeddedOverride = true;

    await AppWindow.restartApplication();

    expect(exitCodes, [AppWindow.restartExitCode]);
    expect(
      await log.readAsString(),
      contains(
        'Restart requested by user, exiting with 75 so systemd restarts the '
        'frontend',
      ),
    );
  });

  test('"Beenden" writes its line, then exits with 0', () async {
    await AppWindow.exitApplication();

    expect(exitCodes, [0]);
    expect(await log.readAsString(), contains('Exit requested by user'));
  });

  test('lines logged just before stay in the file too', () async {
    AppWindow.embeddedOverride = true;
    for (var i = 0; i < 20; i++) {
      AppLogging.frontend.info('line $i');
    }

    await AppWindow.restartApplication();

    final text = await log.readAsString();
    expect(text, contains('line 19'));
    expect(
      text.indexOf('line 19'),
      lessThan(text.indexOf('Restart requested by user')),
    );
  });
}
