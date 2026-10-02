import 'dart:ui' as ui;

import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_controller.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_overlay.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_scope.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/features/camera/data/camera_settings_store.dart';
import 'package:carnine_frontend/features/settings/presentation/models/settings_option_item.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/camera_settings_page.dart';
import 'package:carnine_frontend/features/settings/presentation/settings_content.dart';
import 'package:carnine_frontend/features/settings/presentation/settings_controller.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_grabber/video_grabber.dart';

import '../../fakes/fake_camera_settings_store.dart';

/// Mounts [SettingsContent] with [initialSection] already open (the
/// diagnostics page by default, `null` for the overview), and injected
/// onRestart/onExit fakes - the real [AppWindow] actions call
/// `exit(0)`, which would kill the test process.
Widget _harness({
  required VoidCallback onRestart,
  required VoidCallback onExit,
  SettingsSection? initialSection = SettingsSection.diagnostics,
  CameraSettingsStore? cameraSettingsStore,
  VoidCallback? onShowCamera,
  Locale locale = const Locale('de'),
}) {
  final keyboardController = OnScreenKeyboardController();
  addTearDown(keyboardController.dispose);
  final settingsController = SettingsController(initialSection: initialSection);
  addTearDown(settingsController.dispose);
  final languageController = AppLanguageController();
  addTearDown(languageController.dispose);

  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => OnScreenKeyboardScope(
      controller: keyboardController,
      child: Stack(
        children: [
          child!,
          OnScreenKeyboardOverlay(controller: keyboardController),
        ],
      ),
    ),
    home: Scaffold(
      body: SettingsContent(
        languageController: languageController,
        controller: settingsController,
        onRestart: onRestart,
        onExit: onExit,
        cameraSettingsStore: cameraSettingsStore,
        onShowCamera: onShowCamera,
      ),
    ),
  );
}

void main() {
  testWidgets(
    'diagnostics page shows logs, updates, restart and exit actions',
    (tester) async {
      await tester.pumpWidget(_harness(onRestart: () {}, onExit: () {}));
      await tester.pump();
      await tester.pump();

      expect(find.text('Logansicht öffnen'), findsOneWidget);
      expect(find.text('Nach Updates suchen'), findsOneWidget);
      expect(find.text('Neustart'), findsOneWidget);
      expect(find.text('Beenden'), findsOneWidget);
    },
  );

  testWidgets('checking for updates shows a not-yet-available dialog', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(onRestart: () {}, onExit: () {}));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Nach Updates suchen'));
    await tester.pumpAndSettle();

    expect(find.text('Noch nicht verfügbar'), findsOneWidget);

    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();

    expect(find.text('Noch nicht verfügbar'), findsNothing);
  });

  testWidgets('restart runs immediately, without any confirmation', (
    tester,
  ) async {
    var restarted = false;
    await tester.pumpWidget(
      _harness(onRestart: () => restarted = true, onExit: () {}),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Neustart'));
    await tester.pump();

    expect(restarted, isTrue);
  });

  testWidgets(
    'exit asks for a password first and does not run on a wrong one',
    (tester) async {
      var exited = false;
      await tester.pumpWidget(
        _harness(onRestart: () {}, onExit: () => exited = true),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Beenden'));
      await tester.pumpAndSettle();

      expect(find.text('Passwort erforderlich'), findsOneWidget);

      tester
              .widget<OnScreenTextField>(find.byType(OnScreenTextField))
              .controller
              .text =
          'wrong';
      await tester.pump();
      await tester.tap(find.text('Bestätigen'));
      await tester.pump();

      expect(find.text('Falsches Passwort'), findsOneWidget);
      expect(exited, isFalse);
      // The dialog stays open for another attempt.
      expect(find.text('Passwort erforderlich'), findsOneWidget);
    },
  );

  testWidgets('exit runs after the correct mock password is confirmed', (
    tester,
  ) async {
    var exited = false;
    await tester.pumpWidget(
      _harness(onRestart: () {}, onExit: () => exited = true),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Beenden'));
    await tester.pumpAndSettle();

    tester
            .widget<OnScreenTextField>(find.byType(OnScreenTextField))
            .controller
            .text =
        '4321';
    await tester.pump();
    await tester.tap(find.text('Bestätigen'));
    await tester.pumpAndSettle();

    expect(exited, isTrue);
    expect(find.text('Passwort erforderlich'), findsNothing);
  });

  testWidgets('cancelling the password dialog does not exit', (tester) async {
    var exited = false;
    await tester.pumpWidget(
      _harness(onRestart: () {}, onExit: () => exited = true),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Beenden'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(exited, isFalse);
    expect(find.text('Passwort erforderlich'), findsNothing);
  });

  group('Darstellung & Sprache, Geräte', () {
    Future<void> openOverview(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _harness(onRestart: () {}, onExit: () {}, initialSection: null),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the overview has four tiles in a 2x2 grid', (tester) async {
      await openOverview(tester);

      // The tile's text sits at a height that depends on its subtitle, so
      // compare the tiles themselves.
      Offset tile(String title) => tester.getTopLeft(
        find
            .ancestor(of: find.text(title), matching: find.byType(InkWell))
            .first,
      );
      final maps = tile('Karteneinstellungen');
      final appearance = tile('Darstellung & Sprache');
      final devices = tile('Geräte');
      final system = tile('System');

      expect(appearance.dy, maps.dy);
      expect(appearance.dx, greaterThan(maps.dx));
      expect(devices.dy, greaterThan(maps.dy));
      expect(devices.dx, maps.dx);
      expect(system.dy, devices.dy);
      expect(system.dx, appearance.dx);
      // The language is no tile of its own any more.
      expect(find.text('Sprache'), findsNothing);
    });

    testWidgets('Darstellung & Sprache opens on the language tab', (
      tester,
    ) async {
      await openOverview(tester);

      await tester.tap(find.text('Darstellung & Sprache'));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Aktive Sprache'), findsOneWidget);
      // Both tabs are there, Sprache is the one in use.
      expect(find.text('Darstellung'), findsOneWidget);
      expect(find.text('Sprache'), findsOneWidget);
    });

    testWidgets('the Darstellung tab is a placeholder, and back to Sprache', (
      tester,
    ) async {
      await openOverview(tester);
      await tester.tap(find.text('Darstellung & Sprache'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Darstellung'));
      await tester.pumpAndSettle();

      expect(find.text('Darstellung vorbereitet'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);

      await tester.tap(find.text('Sprache'));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Darstellung vorbereitet'), findsNothing);
    });

    testWidgets('Geräte lists camera, audio, phone app and power supply', (
      tester,
    ) async {
      await openOverview(tester);

      await tester.tap(find.text('Geräte'));
      await tester.pumpAndSettle();

      for (final title in [
        'Kamera',
        'Audio-Ausgang',
        'Handy-App',
        'Netzteil',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(
        find.text('Gerät, Videonorm, Eingang und Bildbreite'),
        findsOneWidget,
      );
    });

    testWidgets('the Geräte rows only show what is coming: not tappable', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openOverview(tester);
      await tester.tap(find.text('Geräte'));
      await tester.pumpAndSettle();

      // No arrow, and nothing in the rows reacts to a touch.
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      await tester.tap(find.text('Kamera'));
      await tester.pumpAndSettle();
      expect(find.text('Audio-Ausgang'), findsOneWidget);
      expect(find.text('Kamera'), findsOneWidget);

      final row = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^Kamera, Gerät')),
      );
      expect(row.flagsCollection.isEnabled, ui.Tristate.isFalse);
      semantics.dispose();
    });
  });

  group('Kamera-Einstellungen (#79)', () {
    Future<void> openDevices(
      WidgetTester tester, {
      FakeCameraSettingsStore? store,
      VoidCallback? onShowCamera,
    }) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _harness(
          onRestart: () {},
          onExit: () {},
          initialSection: SettingsSection.devices,
          cameraSettingsStore: store,
          onShowCamera: onShowCamera,
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openCamera(
      WidgetTester tester,
      FakeCameraSettingsStore store, {
      VoidCallback? onShowCamera,
    }) async {
      await openDevices(tester, store: store, onShowCamera: onShowCamera);
      await tester.tap(find.text('Kamera'));
      await tester.pumpAndSettle();
    }

    FakeCameraSettingsStore twoDevices({GrabberConfig? config}) =>
        FakeCameraSettingsStore(
          config: config ?? const GrabberConfig(),
          devices: const [grabberDevice, usbCameraDevice],
        );

    testWidgets('the Kamera row opens its page, back returns to Geräte', (
      tester,
    ) async {
      await openCamera(tester, twoDevices());

      expect(find.text('GERÄT'), findsOneWidget);
      expect(find.text('VIDEONORM'), findsOneWidget);
      expect(find.text('EINGANG'), findsOneWidget);
      expect(find.text('BILDBREITE'), findsOneWidget);
      // The list of the other device areas is gone.
      expect(find.text('Audio-Ausgang'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Audio-Ausgang'), findsOneWidget);
      expect(find.text('VIDEONORM'), findsNothing);
    });

    testWidgets('only the Kamera row is tappable, the others stay a preview', (
      tester,
    ) async {
      await openDevices(tester, store: twoDevices());

      // One arrow, on the camera row.
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.text('Audio-Ausgang'));
      await tester.pumpAndSettle();

      expect(find.text('Netzteil'), findsOneWidget);
      expect(find.text('VIDEONORM'), findsNothing);
    });

    testWidgets('lists the devices with the saved one selected', (
      tester,
    ) async {
      await openCamera(tester, twoDevices());

      expect(find.text('stk1160'), findsOneWidget);
      expect(find.text('USB PHY 2.0: USB CAMERA'), findsOneWidget);
      expect(find.text('/dev/video1'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('a tap on a norm, input or width saves it at once', (
      tester,
    ) async {
      final store = twoDevices();
      await openCamera(tester, store);

      await tester.tap(find.text('PAL'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('S-Video'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('720'));
      await tester.pumpAndSettle();

      expect(store.saves, ['norm=pal', 'input=4', 'width=720']);
      expect(store.config.norm, VideoNorm.pal);
    });

    testWidgets('a tap on a device saves it, and it becomes the selected one', (
      tester,
    ) async {
      final store = twoDevices();
      await openCamera(tester, store);

      await tester.tap(find.text('USB PHY 2.0: USB CAMERA'));
      await tester.pumpAndSettle();

      expect(store.saves, ['device=/dev/video1']);
      // A USB camera takes none of the grabber's settings.
      expect(
        find.text(
          'Norm, Eingang und Bildbreite gelten nur für analoge Kameras am '
          'USB-Adapter, nicht für USB-Kameras.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('with a USB camera norm, input and width do not react', (
      tester,
    ) async {
      final store = twoDevices(
        config: const GrabberConfig(device: '/dev/video1'),
      );
      await openCamera(tester, store);

      await tester.tap(find.text('PAL'));
      await tester.tap(find.text('720'));
      await tester.pumpAndSettle();

      expect(store.saves, isEmpty);
    });

    testWidgets('a saved device that is not plugged in stays in the list', (
      tester,
    ) async {
      final store = twoDevices(
        config: const GrabberConfig(device: '/dev/video7'),
      );
      await openCamera(tester, store);

      expect(find.text('/dev/video7'), findsOneWidget);
      expect(find.text('Kamera nicht angeschlossen'), findsOneWidget);
    });

    testWidgets('a fixed camera name is not called unplugged', (tester) async {
      const stable = '/dev/v4l/by-id/usb-HDW_Webcam-video-index0';
      final store = twoDevices(config: const GrabberConfig(device: stable));
      await openCamera(tester, store);

      // The list holds /dev/video<n> only, so the link cannot be matched.
      expect(find.text(stable), findsOneWidget);
      expect(find.text('Kamera nicht angeschlossen'), findsNothing);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('without any device it says so and keeps the saved one', (
      tester,
    ) async {
      await openCamera(
        tester,
        FakeCameraSettingsStore(config: const GrabberConfig()),
      );

      // The list is empty and says so; the saved device stays visible.
      expect(find.text('Keine Kamera gefunden'), findsOneWidget);
      expect(find.text('/dev/video0'), findsOneWidget);
      expect(find.text('Kamera nicht angeschlossen'), findsOneWidget);
    });

    testWidgets('a failed save shows a message and keeps the old value', (
      tester,
    ) async {
      final store = twoDevices();
      await openCamera(tester, store);
      store.saveError = StateError('boom');

      await tester.tap(find.text('PAL'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Befehl fehlgeschlagen'), findsOneWidget);
      expect(store.config.norm, VideoNorm.ntsc);

      // Let the message's own timer run out.
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Befehl fehlgeschlagen'), findsNothing);
    });

    testWidgets('Kamerabild ansehen jumps to the camera page', (tester) async {
      var shown = 0;
      await openCamera(tester, twoDevices(), onShowCamera: () => shown++);

      expect(
        find.text('Gilt ab dem nächsten Öffnen der Seite Kamera.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Kamerabild ansehen'));
      await tester.pumpAndSettle();

      expect(shown, 1);
    });

    testWidgets('a backend that is away shows a retry', (tester) async {
      final store = twoDevices()..error = StateError('down');
      await openCamera(tester, store);

      expect(find.text('Erneut versuchen'), findsOneWidget);
      expect(find.text('VIDEONORM'), findsNothing);

      store.error = null;
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();

      expect(find.text('VIDEONORM'), findsOneWidget);
    });

    testWidgets('the camera page is not offered without a backend', (
      tester,
    ) async {
      await openDevices(tester);

      expect(find.byIcon(Icons.chevron_right), findsNothing);
      await tester.tap(find.text('Kamera'));
      await tester.pumpAndSettle();
      expect(find.text('VIDEONORM'), findsNothing);
    });
  });

  group('every language fits the pages at 1024x600', () {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('${locale.languageCode}: overview, tabs, devices, camera', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1024, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = FakeCameraSettingsStore(
          config: const GrabberConfig(device: '/dev/video1', input: 7),
          devices: const [grabberDevice, usbCameraDevice],
        );

        // Overview, then each page; a layout overflow is thrown as an
        // exception and fails the test.
        for (final section in [
          null,
          SettingsSection.appearance,
          SettingsSection.devices,
        ]) {
          // A fresh tree each time, or the first controller would stay.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            _harness(
              onRestart: () {},
              onExit: () {},
              initialSection: section,
              cameraSettingsStore: store,
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        // The camera page, with a USB camera selected: its longest texts.
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();
        expect(find.byType(CameraSettingsPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
