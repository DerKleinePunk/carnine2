import 'package:carnine_frontend/app/app_theme.dart';
import 'package:carnine_frontend/core/keyboard/keyboard_layout.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_controller.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_overlay.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_scope.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/core/navigation/page_guard.dart';
import 'package:carnine_frontend/features/settings/data/install_values_store.dart';
import 'package:carnine_frontend/features/settings/presentation/models/settings_option_item.dart';
import 'package:carnine_frontend/features/settings/presentation/settings_content.dart';
import 'package:carnine_frontend/features/settings/presentation/settings_controller.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/settings_choice_button.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_exit_password_store.dart';
import '../../fakes/fake_install_values_store.dart';

/// "Optionen → System" with the expert page behind it, the keyboard as on
/// the device. [guards] records what the page tells the dashboard.
class _Rig {
  _Rig({FakeInstallValuesStore? store})
    : store = store ?? FakeInstallValuesStore();

  final FakeInstallValuesStore store;
  final FakeExitPasswordStore passwords = FakeExitPasswordStore();
  final OnScreenKeyboardController keyboard = OnScreenKeyboardController();
  PageGuard? guard;

  Widget app({Locale locale = const Locale('de')}) {
    final settings = SettingsController(
      initialSection: SettingsSection.diagnostics,
    );
    addTearDown(settings.dispose);
    final language = AppLanguageController();
    addTearDown(language.dispose);
    addTearDown(keyboard.dispose);

    return MaterialApp(
      theme: CarnineTheme.dark,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => OnScreenKeyboardScope(
        controller: keyboard,
        child: Stack(
          children: [
            child!,
            OnScreenKeyboardOverlay(controller: keyboard),
          ],
        ),
      ),
      home: Scaffold(
        body: SettingsContent(
          languageController: language,
          controller: settings,
          exitPasswordStore: passwords,
          installValuesStore: store,
          onPageGuard: (value) => guard = value,
          onRestart: () {},
          onExit: () {},
        ),
      ),
    );
  }
}

Future<_Rig> _openSystem(
  WidgetTester tester, {
  FakeInstallValuesStore? store,
  Locale locale = const Locale('de'),
}) async {
  tester.view.physicalSize = const Size(1024, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final rig = _Rig(store: store);
  await tester.pumpWidget(rig.app(locale: locale));
  await tester.pumpAndSettle();
  return rig;
}

Future<void> _type(WidgetTester tester, String text) async {
  tester
          .widget<OnScreenTextField>(find.byType(OnScreenTextField))
          .controller
          .text =
      text;
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The tile, the password, the page.
Future<_Rig> _openExperts(
  WidgetTester tester, {
  FakeInstallValuesStore? store,
  Locale locale = const Locale('de'),
}) async {
  final rig = await _openSystem(tester, store: store, locale: locale);
  await tester.tap(find.byIcon(Icons.engineering));
  await tester.pumpAndSettle();
  await _type(tester, '4321');
  await tester.tap(find.byType(TextButton).last);
  await tester.pumpAndSettle();
  return rig;
}

Finder _row(String key) => find.byKey(ValueKey<String>('install-$key'));

/// Scrolls the list until the row of [key] is built and in view: a row
/// below the fold does not exist yet.
Future<void> _show(WidgetTester tester, String key) async {
  final list = find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(_row(key), 120, scrollable: list.first);
  await tester.pumpAndSettle();
}

Finder _inRow(String key, Finder finder) =>
    find.descendant(of: _row(key), matching: finder);

void main() {
  group('the tile on "System" (#207)', () {
    testWidgets('a fourth tile in Wartung, beside the log viewer', (
      tester,
    ) async {
      await _openSystem(tester);

      expect(find.text('Experten'), findsOneWidget);
      expect(find.text('Einbau-Werte, Passwort nötig'), findsOneWidget);
      Offset at(String text) => tester.getTopLeft(find.text(text));
      expect(at('Experten').dy, at('Logansicht öffnen').dy);
      expect(at('Experten').dx, greaterThan(at('Passwort ändern').dx));
    });

    testWidgets('it asks for the exit password; a wrong one keeps it shut', (
      tester,
    ) async {
      final rig = await _openSystem(tester);

      await tester.tap(find.byIcon(Icons.engineering));
      await tester.pumpAndSettle();
      expect(find.text('Passwort erforderlich'), findsOneWidget);
      await _type(tester, 'falsch');
      await tester.tap(find.byType(TextButton).last);
      await tester.pumpAndSettle();

      expect(find.text('Falsches Passwort'), findsOneWidget);
      expect(rig.store.loads, 0);

      await tester.tap(find.byType(TextButton).first);
      await tester.pumpAndSettle();
      expect(find.text('Logansicht öffnen'), findsOneWidget);
    });

    testWidgets('the right one opens the page, with its own header', (
      tester,
    ) async {
      final rig = await _openExperts(tester);

      expect(rig.store.loads, 1);
      expect(find.text('Werte für den Einbau ins Auto'), findsOneWidget);
      expect(find.text('Rückwärtsgang'), findsOneWidget);
      expect(find.text('Quelle'), findsOneWidget);
      expect(find.text('Logansicht öffnen'), findsNothing);
    });

    testWidgets('back without changes goes straight to "System"', (
      tester,
    ) async {
      await _openExperts(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Logansicht öffnen'), findsOneWidget);
      expect(find.text('Änderungen verwerfen?'), findsNothing);
    });
  });

  group('the fields', () {
    testWidgets('help, origin and "gilt nach Neustart" stand in the row', (
      tester,
    ) async {
      await _openExperts(tester);

      expect(
        find.text('Woher das Backend den Rückwärtsgang liest.'),
        findsOneWidget,
      );
      expect(
        _inRow('reverse_gear.source', find.text('Vorgabe')),
        findsOneWidget,
      );
      await _show(tester, 'audio.rear_percent');
      expect(
        _inRow(
          'audio.rear_percent',
          find.text('99-ui.toml · gilt nach Neustart'),
        ),
        findsOneWidget,
      );
      expect(_inRow('audio.rear_percent', find.text('30 %')), findsOneWidget);
    });

    testWidgets('a choice of three stands as buttons; a tap changes it', (
      tester,
    ) async {
      await _openExperts(tester);

      final gpio = _inRow('reverse_gear.source', find.text('GPIO'));
      await _tap(tester, gpio);

      final button = tester.widget<SettingsChoiceButton>(
        find.ancestor(of: gpio, matching: find.byType(SettingsChoiceButton)),
      );
      expect(button.isSelected, isTrue);
      expect(
        _inRow('reverse_gear.source', find.text('geändert')),
        findsOneWidget,
      );
      expect(find.text('Geänderte Werte: 1'), findsOneWidget);
    });

    testWidgets('a switch changes with a tap on its row', (tester) async {
      await _openExperts(tester);

      await _show(tester, 'power_supply.enabled');
      await _tap(
        tester,
        _inRow('power_supply.enabled', find.text('Netzteil angeschlossen')),
      );

      expect(
        _inRow('power_supply.enabled', find.text('geändert')),
        findsOneWidget,
      );
    });

    testWidgets('a number opens on the digits and keeps to its range', (
      tester,
    ) async {
      final rig = await _openExperts(tester);

      await _tap(
        tester,
        _inRow('reverse_gear.gpio_line', find.text('GPIO-Leitung')),
      );
      expect(rig.keyboard.isOpen, isTrue);
      expect(rig.keyboard.layer, KeyboardLayer.numbersSymbols);
      expect(find.text('Erlaubt: 0 bis 511'), findsOneWidget);

      await _type(tester, '600');
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bitte geben Sie eine ganze Zahl von 0 bis 511 ein.'),
        findsOneWidget,
      );

      await _type(tester, '26');
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      expect(_inRow('reverse_gear.gpio_line', find.text('26')), findsOneWidget);
    });

    testWidgets('a text opens on the letters with its length', (tester) async {
      final rig = await _openExperts(tester);

      await _tap(
        tester,
        _inRow('reverse_gear.gpio_chip', find.text('GPIO-Chip')),
      );

      expect(rig.keyboard.layer, KeyboardLayer.letters);
      expect(find.text('Höchstens 64 Zeichen'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(find.text('Geänderte Werte: 1'), findsNothing);
    });

    testWidgets('a sound card offers the system default first; a card the '
        'device lacks stays visible', (tester) async {
      final store = FakeInstallValuesStore();
      store.values = [
        for (final value in store.values)
          if (value.key == 'audio.output_card')
            InstallValue(
              key: value.key,
              group: value.group,
              label: value.label,
              kind: value.kind,
              choices: value.choices,
              optional: true,
              value: 'vc4hdmi1',
              origin: '/etc/carnine/config.d/99-ui.toml',
            )
          else
            value,
      ];
      await _openExperts(tester, store: store);

      const key = 'audio.output_card';
      await _show(tester, 'audio.output_card');
      expect(_inRow(key, find.text('Vorgabe des Systems')), findsOneWidget);
      expect(
        _inRow(key, find.text('vc4hdmi1 (nicht gefunden)')),
        findsOneWidget,
      );

      await _tap(tester, _inRow(key, find.text('Vorgabe des Systems')));
      expect(_inRow(key, find.text('wird zurückgesetzt')), findsOneWidget);
    });

    testWidgets('more than four choices open a list', (tester) async {
      await _openExperts(tester);

      await _show(tester, 'audio.test_many');
      await _tap(tester, _inRow('audio.test_many', find.text('Viele')));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Vier'));
      await tester.pumpAndSettle();

      expect(_inRow('audio.test_many', find.text('Vier')), findsOneWidget);
      expect(_inRow('audio.test_many', find.text('geändert')), findsOneWidget);
    });

    testWidgets('"Zurücksetzen" only for an optional value that is set', (
      tester,
    ) async {
      await _openExperts(tester);

      expect(
        _inRow('reverse_gear.gpio_line', find.text('Zurücksetzen')),
        findsNothing,
      );
      await _show(tester, 'audio.rear_percent');
      expect(
        _inRow('audio.rear_percent', find.text('Zurücksetzen')),
        findsOneWidget,
      );
      expect(
        _inRow('reverse_gear.source', find.text('Zurücksetzen')),
        findsNothing,
      );

      await _tap(
        tester,
        _inRow('audio.rear_percent', find.text('Zurücksetzen')),
      );
      expect(_inRow('audio.rear_percent', find.text('100 %')), findsOneWidget);
      expect(
        _inRow('audio.rear_percent', find.textContaining('wird zurückgesetzt')),
        findsOneWidget,
      );
    });
  });

  group('a long sound card name (#207)', () {
    const longName = 'USB - HDW Webcam USB Audio Device, USB Audio';

    /// The sound card row with [count] cards, the last with a long name.
    FakeInstallValuesStore storeWith(int count) {
      final store = FakeInstallValuesStore();
      store.values = [
        for (final value in store.values)
          if (value.key == 'audio.output_card')
            InstallValue(
              key: value.key,
              group: value.group,
              label: value.label,
              kind: value.kind,
              optional: true,
              choices: [
                for (var i = 1; i < count; i++)
                  InstallValueChoice(value: 'card$i', label: 'Karte $i'),
                const InstallValueChoice(value: 'webcam', label: longName),
              ],
            )
          else
            value,
      ];
      return store;
    }

    /// Wraps instead of being cut, and keeps 16 from the frame.
    void expectWrapped(WidgetTester tester, Finder name) {
      final text = tester.widget<Text>(name);
      expect(text.maxLines, 3);
      final button = find.ancestor(
        of: name,
        matching: find.byType(SettingsChoiceButton),
      );
      final frame = tester.getRect(button);
      final label = tester.getRect(name);
      expect(label.height, greaterThan(20), reason: 'more than one line');
      expect(label.left - frame.left, greaterThanOrEqualTo(16));
      expect(frame.right - label.right, greaterThanOrEqualTo(16));
      expect(tester.takeException(), isNull);
    }

    testWidgets('in the list it breaks into lines, away from the frame', (
      tester,
    ) async {
      await _openExperts(tester, store: storeWith(5));
      await _show(tester, 'audio.output_card');

      await _tap(tester, _inRow('audio.output_card', find.text('Ausgang')));
      final name = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(longName),
      );

      expectWrapped(tester, name);
    });

    testWidgets('as a button in the row as well, the row as high as it', (
      tester,
    ) async {
      await _openExperts(tester, store: storeWith(3));
      await _show(tester, 'audio.output_card');

      final name = _inRow('audio.output_card', find.text(longName));
      expectWrapped(tester, name);
      final buttons = _inRow(
        'audio.output_card',
        find.byType(SettingsChoiceButton),
      );
      final heights = {
        for (final element in buttons.evaluate())
          tester.getSize(find.byWidget(element.widget)).height,
      };
      expect(heights, hasLength(1), reason: 'all as high as the tallest');
    });
  });

  group('the notices over the list', () {
    testWidgets('a page file that was left out, with the reason', (
      tester,
    ) async {
      await _openExperts(
        tester,
        store: FakeInstallValuesStore(
          uiDropInError: 'reverse_gear.gpio_line is required for source gpio',
        ),
      );

      expect(
        find.text('Einbau-Einstellungen ungültig, vorige Fassung aktiv'),
        findsOneWidget,
      );
      expect(
        find.text('reverse_gear.gpio_line is required for source gpio'),
        findsOneWidget,
      );
    });

    testWidgets('values waiting for a restart', (tester) async {
      await _openExperts(
        tester,
        store: FakeInstallValuesStore(restartRequired: true),
      );

      expect(
        find.text(
          'Markierte Werte gelten erst nach einem Neustart des Geräts.',
        ),
        findsOneWidget,
      );
    });
  });

  group('saving', () {
    testWidgets('"Speichern" sends the changed keys with the password', (
      tester,
    ) async {
      final rig = await _openExperts(tester);
      await _tap(tester, _inRow('reverse_gear.source', find.text('Demo')));
      await _show(tester, 'power_supply.enabled');
      await _tap(
        tester,
        _inRow('power_supply.enabled', find.text('Netzteil angeschlossen')),
      );
      expect(find.text('Geänderte Werte: 2'), findsOneWidget);

      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      final save = rig.store.saves.single;
      expect(save.password, '4321');
      expect(save.changes.map((change) => '${change.key}=${change.value}'), [
        'reverse_gear.source=demo',
        'power_supply.enabled=true',
      ]);
      expect(find.text('Gespeichert'), findsOneWidget);
      expect(find.text('Speichern'), findsNothing);
      expect(rig.store.restartRequired, isTrue);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Gespeichert'), findsNothing);
    });

    testWidgets('"Verwerfen" drops the changes', (tester) async {
      final rig = await _openExperts(tester);
      await _tap(tester, _inRow('reverse_gear.source', find.text('Demo')));

      await tester.tap(find.text('Verwerfen'));
      await tester.pumpAndSettle();

      expect(find.text('Geänderte Werte: 1'), findsNothing);
      expect(rig.store.saves, isEmpty);
    });

    testWidgets('a refused value says why and keeps the changes', (
      tester,
    ) async {
      final store = FakeInstallValuesStore()
        ..saveError = const InstallValuesException(
          InstallValuesFailure.rejected,
          'Konfiguration ungültig: gpio_line is required',
        );
      await _openExperts(tester, store: store);
      await _tap(tester, _inRow('reverse_gear.source', find.text('GPIO')));

      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Nicht gespeichert: Konfiguration ungültig: gpio_line is required',
        ),
        findsOneWidget,
      );
      expect(find.text('Speichern'), findsOneWidget);
    });

    testWidgets('a password changed meanwhile is asked again, then it saves', (
      tester,
    ) async {
      final rig = await _openExperts(tester);
      rig.passwords.password = 'neu1';
      rig.store.password = 'neu1';
      await _tap(tester, _inRow('reverse_gear.source', find.text('Demo')));

      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Passwort erforderlich'), findsOneWidget);
      await _type(tester, 'neu1');
      await tester.tap(find.text('Bestätigen'));
      await tester.pumpAndSettle();

      expect(rig.store.saves.map((save) => save.password), ['4321', 'neu1']);
      expect(find.text('Gespeichert'), findsOneWidget);
    });
  });

  group('leaving with unsaved changes', () {
    testWidgets('back asks; Abbrechen stays, Verwerfen leaves', (tester) async {
      await _openExperts(tester);
      await _tap(tester, _inRow('reverse_gear.source', find.text('Demo')));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Änderungen verwerfen?'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(find.text('Geänderte Werte: 1'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Verwerfen'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Logansicht öffnen'), findsOneWidget);
    });

    testWidgets('the dashboard learns of them, and its question asks too', (
      tester,
    ) async {
      final rig = await _openExperts(tester);
      final guard = rig.guard;
      expect(guard, isNotNull);
      expect(guard?.isActive(), isFalse);

      await _tap(tester, _inRow('reverse_gear.source', find.text('Demo')));
      expect(guard?.isActive(), isTrue);

      final leave = guard?.confirmLeave();
      await tester.pumpAndSettle();
      expect(find.text('Änderungen verwerfen?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Verwerfen'),
        ),
      );
      await tester.pumpAndSettle();
      expect(await leave, isTrue);
      expect(guard?.isActive(), isFalse);
    });
  });

  group('every language fits at 1024x600', () {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('${locale.languageCode}: tile, page, a change, a dialog', (
        tester,
      ) async {
        await _openExperts(
          tester,
          locale: locale,
          store: FakeInstallValuesStore(
            restartRequired: true,
            uiDropInError: 'reverse_gear.gpio_line is required',
          ),
        );
        expect(tester.takeException(), isNull);

        await _tap(tester, _inRow('reverse_gear.source', find.text('Demo')));
        expect(tester.takeException(), isNull);

        await _tap(
          tester,
          _inRow('reverse_gear.gpio_line', find.text('GPIO-Leitung')),
        );
        await _type(tester, '999');
        await tester.tap(find.byType(TextButton).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
