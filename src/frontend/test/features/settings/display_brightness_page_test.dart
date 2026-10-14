import 'package:carnine_frontend/features/settings/data/display_brightness_store.dart';
import 'package:carnine_frontend/features/settings/presentation/models/settings_option_item.dart';
import 'package:carnine_frontend/features/settings/presentation/settings_content.dart';
import 'package:carnine_frontend/features/settings/presentation/settings_controller.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_display_brightness_store.dart';

Widget _harness(
  DisplayBrightnessStore? store, {
  Locale locale = const Locale('de'),
}) {
  final settingsController = SettingsController(
    initialSection: SettingsSection.devices,
  );
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
    home: Scaffold(
      body: SettingsContent(
        languageController: languageController,
        controller: settingsController,
        displayBrightnessStore: store,
        onRestart: () {},
        onExit: () {},
      ),
    ),
  );
}

Future<void> _open(
  WidgetTester tester,
  DisplayBrightnessStore? store, {
  Locale locale = const Locale('de'),
}) async {
  tester.view.physicalSize = const Size(1024, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_harness(store, locale: locale));
  await tester.pumpAndSettle();
}

/// The row of the list is the `InkWell` around its title.
InkWell _row(WidgetTester tester, String title) => tester.widget<InkWell>(
  find.ancestor(of: find.text(title), matching: find.byType(InkWell)).first,
);

Slider _slider(WidgetTester tester) =>
    tester.widget<Slider>(find.byType(Slider));

Future<void> _openDisplayPage(WidgetTester tester) async {
  await tester.tap(find.text('Display'));
  await tester.pumpAndSettle();
}

void main() {
  group('the row Display on Geräte (#102)', () {
    testWidgets('sits under Kamera, in the list of five', (tester) async {
      await _open(tester, FakeDisplayBrightnessStore());

      for (final title in [
        'Kamera',
        'Display',
        'Audio-Ausgang',
        'Handy-App',
        'Netzteil',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(
        tester.getTopLeft(find.text('Display')).dy,
        greaterThan(tester.getTopLeft(find.text('Kamera')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Display')).dy,
        lessThan(tester.getTopLeft(find.text('Audio-Ausgang')).dy),
      );
    });

    testWidgets('a display with a backlight can be tapped', (tester) async {
      await _open(tester, FakeDisplayBrightnessStore());

      expect(_row(tester, 'Display').onTap, isNotNull);
      expect(find.text('Helligkeit des Displays'), findsOneWidget);
    });

    testWidgets('a display that is not modified is grey, with the reason, and '
        'cannot be tapped', (tester) async {
      await _open(
        tester,
        FakeDisplayBrightnessStore(configured: false, available: false),
      );

      expect(_row(tester, 'Display').onTap, isNull);
      expect(
        find.text('Dieses Display hat keine Helligkeitsregelung'),
        findsOneWidget,
      );
      expect(find.text('Helligkeit des Displays'), findsNothing);

      await tester.tap(find.text('Display'));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('while the backend has not answered, or is away, it is grey '
        'and quiet', (tester) async {
      await _open(
        tester,
        FakeDisplayBrightnessStore()..loadError = StateError('down'),
      );

      expect(_row(tester, 'Display').onTap, isNull);
      expect(find.text('Helligkeit des Displays'), findsOneWidget);
    });

    testWidgets('without a backend it is a preview like the rest', (
      tester,
    ) async {
      await _open(tester, null);

      expect(_row(tester, 'Display').onTap, isNull);
      expect(find.text('Helligkeit des Displays'), findsOneWidget);
    });

    testWidgets('the subtitle of the page names the display too', (
      tester,
    ) async {
      await _open(tester, FakeDisplayBrightnessStore());

      expect(
        find.text('Kamera, Display, Audio-Ausgang, Handy-App und Netzteil'),
        findsOneWidget,
      );
    });
  });

  group('the page Display', () {
    testWidgets('shows the level, the ends and the hint', (tester) async {
      await _open(tester, FakeDisplayBrightnessStore(percent: 60));
      await _openDisplayPage(tester);

      expect(find.text('Helligkeit'), findsOneWidget);
      expect(find.text('60 %'), findsOneWidget);
      expect(_slider(tester).value, 60);
      expect(_slider(tester).max, 100);
      expect(find.text('dunkel'), findsOneWidget);
      expect(find.text('hell'), findsOneWidget);
      expect(
        find.text('Die dunkelste Stufe schaltet das Display nicht aus.'),
        findsOneWidget,
      );
    });

    testWidgets('the header has its own title and the way back', (
      tester,
    ) async {
      await _open(tester, FakeDisplayBrightnessStore());
      await _openDisplayPage(tester);

      expect(find.text('Helligkeit des Displays'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Kamera'), findsOneWidget);
    });

    testWidgets('the display follows the thumb: a drag is sent while it '
        'goes, and again when it is let go', (tester) async {
      final store = FakeDisplayBrightnessStore();
      await _open(tester, store);
      await _openDisplayPage(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Slider)),
      );
      await gesture.moveBy(const Offset(-120, 0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(store.saves, isNotEmpty, reason: 'sent while it is dragged');
      final whileDragging = store.saves.length;

      await gesture.moveBy(const Offset(-120, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(store.saves.length, greaterThan(whileDragging));
      expect(store.percent, lessThan(100));
      expect(_slider(tester).value, store.percent);
    });

    testWidgets('a change that fails shows the message and goes back', (
      tester,
    ) async {
      final store = FakeDisplayBrightnessStore();
      await _open(tester, store);
      await _openDisplayPage(tester);
      store.saveError = StateError('no');

      await tester.drag(find.byType(Slider), const Offset(-300, 0));
      await tester.pump();
      await tester.pump();

      expect(find.text('Befehl fehlgeschlagen'), findsOneWidget);
      expect(_slider(tester).value, 100);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Befehl fehlgeschlagen'), findsNothing);
    });

    testWidgets('a channel that cannot be driven greys the slider out and '
        'says so', (tester) async {
      final store = FakeDisplayBrightnessStore(available: false);
      await _open(tester, store);
      await _openDisplayPage(tester);

      expect(_slider(tester).onChanged, isNull);
      expect(
        find.text('Die Helligkeit lässt sich gerade nicht ändern.'),
        findsOneWidget,
      );
      await tester.drag(find.byType(Slider), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(store.saves, isEmpty);
    });
  });

  group('every language fits the list and the page at 1024x600', () {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('${locale.languageCode}: list, page, not set up, error', (
        tester,
      ) async {
        final store = FakeDisplayBrightnessStore();
        await _open(tester, store, locale: locale);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byIcon(Icons.brightness_6).first);
        await tester.pumpAndSettle();
        expect(find.byType(Slider), findsOneWidget);
        store.saveError = StateError('no');
        await tester.drag(find.byType(Slider), const Offset(-300, 0));
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 5));

        await tester.pumpWidget(const SizedBox.shrink());
        await _open(
          tester,
          FakeDisplayBrightnessStore(configured: false, available: false),
          locale: locale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
