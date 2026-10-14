import 'package:carnine_frontend/features/maps/presentation/map_follow_zoom_controller.dart';
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
import '../../fakes/fake_map_follow_zoom_store.dart';

Widget _harness(
  MapFollowZoomController? followZoom, {
  Locale locale = const Locale('de'),
}) {
  final settingsController = SettingsController(
    initialSection: SettingsSection.maps,
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
        announcementSettingsStore: FakeAnnouncementSettingsStore(),
        followZoomController: followZoom,
        onRestart: () {},
        onExit: () {},
      ),
    ),
  );
}

Future<MapFollowZoomController> _open(
  WidgetTester tester,
  FakeMapFollowZoomStore? store, {
  Locale locale = const Locale('de'),
  bool openTab = true,
}) async {
  tester.view.physicalSize = const Size(1024, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = MapFollowZoomController(store: store);
  addTearDown(controller.dispose);
  await tester.runAsync(controller.load);
  await tester.pumpWidget(_harness(controller, locale: locale));
  await tester.pumpAndSettle();
  if (openTab) {
    await tester.tap(find.byType(SettingsChoiceButton).at(1));
    await tester.pumpAndSettle();
  }
  return controller;
}

Slider _slider(WidgetTester tester) =>
    tester.widget<Slider>(find.byType(Slider));

void main() {
  group('the tab Karte (#131)', () {
    testWidgets('shows the title, the explanation, the levels and the ends', (
      tester,
    ) async {
      await _open(tester, FakeMapFollowZoomStore());

      expect(find.text('Zoom beim Folgen'), findsOneWidget);
      expect(find.textContaining('Je höher die Stufe'), findsOneWidget);
      expect(find.textContaining('Vorgabe'), findsNothing);
      for (final level in ['14', '15', '17']) {
        expect(find.text(level), findsOneWidget, reason: level);
      }
      // 16 is the value and a level under the slider.
      expect(find.text('16'), findsNWidgets(2));
      expect(find.text('weit'), findsOneWidget);
      expect(find.text('nah'), findsOneWidget);
    });

    testWidgets('the slider has the four levels 14 to 17, at 16 without a '
        'saved one', (tester) async {
      await _open(tester, FakeMapFollowZoomStore());

      final slider = _slider(tester);
      expect(slider.min, 14);
      expect(slider.max, 17);
      expect(slider.divisions, 3);
      expect(slider.value, 16);
    });

    testWidgets('shows the level the backend has', (tester) async {
      await _open(tester, FakeMapFollowZoomStore(zoom: 14));

      expect(_slider(tester).value, 14);
    });

    testWidgets('a level outside the slider does not break it', (tester) async {
      await _open(tester, FakeMapFollowZoomStore(zoom: 22));

      expect(_slider(tester).value, 17);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the map level is saved when the thumb is let go', (
      tester,
    ) async {
      final store = FakeMapFollowZoomStore();
      final controller = await _open(tester, store);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Slider)),
      );
      await gesture.moveBy(const Offset(-800, 0));
      await tester.pump();
      expect(store.saves, isEmpty, reason: 'nothing while it is dragged');
      expect(find.text('14'), findsNWidgets(2));
      expect(controller.zoom, 16, reason: 'the map stays until it is let go');

      await gesture.up();
      await tester.pumpAndSettle();

      expect(store.saves, [14]);
      expect(controller.zoom, 14);
      expect(_slider(tester).value, 14);
    });

    testWidgets('a save that fails shows the message and goes back', (
      tester,
    ) async {
      final store = FakeMapFollowZoomStore();
      final controller = await _open(tester, store);
      store.saveError = StateError('no');

      await tester.drag(find.byType(Slider), const Offset(800, 0));
      await tester.pump();
      await tester.pump();

      expect(find.text('Befehl fehlgeschlagen'), findsOneWidget);
      expect(controller.zoom, 16);
      expect(_slider(tester).value, 16);

      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Befehl fehlgeschlagen'), findsNothing);
    });

    testWidgets('without the controller the tab stays the placeholder', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_harness(null));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SettingsChoiceButton).at(1));
      await tester.pumpAndSettle();

      expect(find.text('Karteneinstellungen vorbereitet'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });
  });

  group('every language fits the tab at 1024x600', () {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('${locale.languageCode}: with and without an error', (
        tester,
      ) async {
        final store = FakeMapFollowZoomStore();
        await _open(tester, store, locale: locale);
        expect(tester.takeException(), isNull);

        store.saveError = StateError('no');
        await tester.drag(find.byType(Slider), const Offset(800, 0));
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 5));
      });
    }
  });
}
