import 'package:carnine_frontend/features/settings/data/announcement_settings_store.dart';
import 'package:carnine_frontend/features/settings/presentation/models/settings_option_item.dart';
import 'package:carnine_frontend/features/settings/presentation/settings_content.dart';
import 'package:carnine_frontend/features/settings/presentation/settings_controller.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/settings_choice_button.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_announcement_settings_store.dart';

Widget _harness(
  AnnouncementSettingsStore? store, {
  Locale locale = const Locale('de'),
  SettingsSection? section = SettingsSection.maps,
}) {
  final settingsController = SettingsController(initialSection: section);
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
        announcementSettingsStore: store,
        onRestart: () {},
        onExit: () {},
      ),
    ),
  );
}

Future<void> _open(
  WidgetTester tester,
  AnnouncementSettingsStore? store, {
  Locale locale = const Locale('de'),
  SettingsSection? section = SettingsSection.maps,
}) async {
  tester.view.physicalSize = const Size(1024, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_harness(store, locale: locale, section: section));
  await tester.pumpAndSettle();
}

Slider _slider(WidgetTester tester, int index) =>
    tester.widget<Slider>(find.byType(Slider).at(index));

void main() {
  group('Karteneinstellungen (#110)', () {
    testWidgets('open on the tab Ansagen, with the second tab Karte', (
      tester,
    ) async {
      await _open(tester, FakeAnnouncementSettingsStore());

      expect(find.text('Ansagen'), findsOneWidget);
      expect(find.text('Karte'), findsOneWidget);
      expect(find.text('Sprachansagen'), findsOneWidget);
      expect(find.text('Lautstärke der Ansagen'), findsOneWidget);
      expect(find.text('Musik während einer Ansage'), findsOneWidget);
      expect(find.text('Ansage testen'), findsOneWidget);
    });

    testWidgets('the tab Karte is the placeholder, and back', (tester) async {
      await _open(tester, FakeAnnouncementSettingsStore());

      await tester.tap(find.text('Karte'));
      await tester.pumpAndSettle();
      expect(find.text('Karteneinstellungen vorbereitet'), findsOneWidget);
      expect(find.text('Sprachansagen'), findsNothing);

      await tester.tap(find.text('Ansagen'));
      await tester.pumpAndSettle();
      expect(find.text('Sprachansagen'), findsOneWidget);
    });

    testWidgets('without a backend it stays the placeholder as before', (
      tester,
    ) async {
      await _open(tester, null);

      expect(find.text('Karteneinstellungen vorbereitet'), findsOneWidget);
      expect(find.text('Sprachansagen'), findsNothing);
    });

    testWidgets('shows what the backend keeps', (tester) async {
      await _open(
        tester,
        FakeAnnouncementSettingsStore(
          settings: const AnnouncementSettings(
            available: true,
            enabled: false,
            volumePercent: 70,
            musicUnderPercent: 0,
          ),
        ),
      );

      expect(find.text('70 %'), findsOneWidget);
      expect(find.text('0 %'), findsOneWidget);
      expect(_slider(tester, 0).value, 70);
      expect(_slider(tester, 1).value, 0);
    });

    testWidgets('the hint under the music says what 0 % means', (tester) async {
      await _open(tester, FakeAnnouncementSettingsStore());

      expect(
        find.textContaining('Bei 0 % hält die Musik während einer Ansage an'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Bei 100 % bleibt sie gleich laut'),
        findsOneWidget,
      );
    });
  });

  group('the switch', () {
    testWidgets('a tap on the card switches the announcements off', (
      tester,
    ) async {
      final store = FakeAnnouncementSettingsStore();
      await _open(tester, store);

      await tester.tap(find.text('Sprachansagen'));
      await tester.pumpAndSettle();

      expect(store.saves, ['enabled=false']);
      final test = find.widgetWithText(ElevatedButton, 'Ansage testen');
      expect(tester.widget<ElevatedButton>(test).onPressed, isNull);
    });

    testWidgets('and on again', (tester) async {
      final store = FakeAnnouncementSettingsStore(
        settings: const AnnouncementSettings(
          available: true,
          enabled: false,
          volumePercent: 100,
          musicUnderPercent: 30,
        ),
      );
      await _open(tester, store);

      await tester.tap(find.text('Sprachansagen'));
      await tester.pumpAndSettle();

      expect(store.saves, ['enabled=true']);
    });
  });

  group('the sliders', () {
    testWidgets('a drag is sent when the thumb is let go', (tester) async {
      final store = FakeAnnouncementSettingsStore();
      await _open(tester, store);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Slider).first),
      );
      await gesture.moveBy(const Offset(-150, 0));
      await tester.pump();
      expect(store.saves, isEmpty, reason: 'nothing while it is dragged');
      expect(_slider(tester, 0).value, lessThan(100));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(store.saves, hasLength(1));
      expect(store.saves.single, startsWith('volume='));
      expect(store.settings.volumePercent, lessThan(100));
      expect(_slider(tester, 0).value, store.settings.volumePercent);
    });

    testWidgets('the music slider goes to 0 and sends 0', (tester) async {
      final store = FakeAnnouncementSettingsStore();
      await _open(tester, store);

      await tester.drag(find.byType(Slider).at(1), const Offset(-800, 0));
      await tester.pumpAndSettle();

      expect(store.saves, ['musicUnder=0']);
      expect(find.text('0 %'), findsOneWidget);
    });

    testWidgets('a save that fails shows the message and the old value', (
      tester,
    ) async {
      final store = FakeAnnouncementSettingsStore()
        ..saveError = StateError('no');
      await _open(tester, store);

      await tester.drag(find.byType(Slider).first, const Offset(-200, 0));
      await tester.pump();
      await tester.pump();

      expect(find.text('Befehl fehlgeschlagen'), findsOneWidget);
      expect(_slider(tester, 0).value, 100);

      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Befehl fehlgeschlagen'), findsNothing);
    });
  });

  group('the test announcement', () {
    testWidgets('speaks the example sentence and is on while it runs', (
      tester,
    ) async {
      final store = FakeAnnouncementSettingsStore();
      await _open(tester, store);

      await tester.tap(find.text('Ansage testen'));
      await tester.pumpAndSettle();

      expect(store.spoken, ['In 300 Metern rechts abbiegen.']);
    });

    testWidgets('the sentence is German in every display language', (
      tester,
    ) async {
      final store = FakeAnnouncementSettingsStore();
      await _open(tester, store, locale: const Locale('en'));

      await tester.tap(find.text('Test announcement'));
      await tester.pumpAndSettle();

      expect(store.spoken, ['In 300 Metern rechts abbiegen.']);
    });
  });

  group('without a voice', () {
    FakeAnnouncementSettingsStore withoutVoice() =>
        FakeAnnouncementSettingsStore(
          settings: const AnnouncementSettings(
            available: false,
            enabled: true,
            volumePercent: 100,
            musicUnderPercent: 30,
          ),
        );

    testWidgets('says so, and nothing can be changed', (tester) async {
      final store = withoutVoice();
      await _open(tester, store);

      expect(find.text('Keine Stimme installiert'), findsOneWidget);
      expect(_slider(tester, 0).onChanged, isNull);
      expect(_slider(tester, 1).onChanged, isNull);

      await tester.tap(find.text('Sprachansagen'));
      await tester.pumpAndSettle();
      final test = find.widgetWithText(ElevatedButton, 'Ansage testen');
      expect(tester.widget<ElevatedButton>(test).onPressed, isNull);
      expect(store.saves, isEmpty);
    });
  });

  group('the backend', () {
    testWidgets('being away shows a retry, and the page comes back', (
      tester,
    ) async {
      final store = FakeAnnouncementSettingsStore()
        ..loadError = StateError('down');
      await _open(tester, store);

      expect(find.text('Erneut versuchen'), findsOneWidget);
      expect(find.text('Sprachansagen'), findsNothing);

      store.loadError = null;
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();

      expect(find.text('Sprachansagen'), findsOneWidget);
    });
  });

  group('every language fits the page at 1024x600', () {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('${locale.languageCode}: both tabs, with and without voice', (
        tester,
      ) async {
        for (final available in [true, false]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await _open(
            tester,
            FakeAnnouncementSettingsStore(
              settings: AnnouncementSettings(
                available: available,
                enabled: true,
                volumePercent: 100,
                musicUnderPercent: 30,
              ),
            ),
            locale: locale,
          );
          expect(tester.takeException(), isNull);

          final store = FakeAnnouncementSettingsStore()
            ..saveError = StateError('no');
          await tester.pumpWidget(const SizedBox.shrink());
          await _open(tester, store, locale: locale);
          await tester.drag(find.byType(Slider).first, const Offset(-200, 0));
          await tester.pump();
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(seconds: 5));
        }

        // The second tab as well.
        await tester.tap(find.byType(SettingsChoiceButton).at(1));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
