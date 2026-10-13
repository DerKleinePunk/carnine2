import 'dart:async';

import 'package:carnine_frontend/app/app_theme.dart';
import 'package:carnine_frontend/core/app_version.dart';
import 'package:carnine_frontend/core/keyboard/keyboard_panel.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_controller.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_overlay.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_scope.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/core/logging/log_viewer_dialog.dart';
import 'package:carnine_frontend/features/settings/data/exit_password_store.dart';
import 'package:carnine_frontend/features/settings/presentation/models/settings_option_item.dart';
import 'package:carnine_frontend/features/settings/presentation/settings_content.dart';
import 'package:carnine_frontend/features/settings/presentation/settings_controller.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_exit_password_store.dart';

Widget _harness({
  required VoidCallback onRestart,
  required VoidCallback onExit,
  ExitPasswordStore? store,
  Locale locale = const Locale('de'),
}) {
  final keyboardController = OnScreenKeyboardController();
  addTearDown(keyboardController.dispose);
  final settingsController = SettingsController(
    initialSection: SettingsSection.diagnostics,
  );
  addTearDown(settingsController.dispose);
  final languageController = AppLanguageController();
  addTearDown(languageController.dispose);

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
        exitPasswordStore: store,
        onRestart: onRestart,
        onExit: onExit,
      ),
    ),
  );
}

Future<void> _open(
  WidgetTester tester, {
  VoidCallback? onRestart,
  VoidCallback? onExit,
  ExitPasswordStore? store,
  Locale locale = const Locale('de'),
}) async {
  tester.view.physicalSize = const Size(1024, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _harness(
      onRestart: onRestart ?? () {},
      onExit: onExit ?? () {},
      store: store,
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

/// Types into the field of the open dialog; the on-screen keyboard writes
/// into the same controller.
Future<void> _type(WidgetTester tester, String text) async {
  tester
          .widget<OnScreenTextField>(find.byType(OnScreenTextField))
          .controller
          .text =
      text;
  await tester.pump();
}

Future<void> _tapAndSettle(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// A button of the open dialog - "Fertig" is also a key of the keyboard.
Future<void> _tapDialogButton(WidgetTester tester, String text) async {
  await tester.tap(
    find.descendant(of: find.byType(AlertDialog), matching: find.text(text)),
  );
  await tester.pumpAndSettle();
}

/// Top edge of the on-screen keyboard: 308 when it is open, 600 when it has
/// slid out of the display.
double _keyboardTop(WidgetTester tester) =>
    tester.getTopLeft(find.byType(KeyboardPanel)).dy;

Rect _dialogRect(WidgetTester tester) => tester.getRect(
  find
      .descendant(of: find.byType(AlertDialog), matching: find.byType(Material))
      .first,
);

/// Runs [body] as on the Pi: on Linux a field loses the focus, and the
/// keyboard with it, when anything outside of it is tapped.
Future<void> _onLinux(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

String _fieldText(WidgetTester tester) => tester
    .widget<OnScreenTextField>(find.byType(OnScreenTextField))
    .controller
    .text;

void main() {
  group('System page', () {
    testWidgets('has six tiles in two groups, and no inline logs', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text('Wartung'), findsOneWidget);
      expect(find.text('Oberfläche'), findsOneWidget);
      for (final title in [
        'Logansicht öffnen',
        'Nach Updates suchen',
        'Passwort ändern',
        'Neustart',
        'Beenden',
        'Version',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text('Aktuelle Frontend-Logs'), findsNothing);

      Offset at(String title) => tester.getTopLeft(
        find.ancestor(of: find.text(title), matching: find.byType(InkWell)),
      );
      expect(at('Nach Updates suchen').dy, at('Logansicht öffnen').dy);
      expect(at('Passwort ändern').dy, at('Logansicht öffnen').dy);
      expect(at('Beenden').dy, at('Neustart').dy);
      expect(at('Neustart').dy, greaterThan(at('Logansicht öffnen').dy));
      expect(at('Beenden').dx, greaterThan(at('Neustart').dx));
    });

    testWidgets('Logansicht öffnen shows the log viewer', (tester) async {
      await _open(tester);

      await _tapAndSettle(tester, 'Logansicht öffnen');

      expect(find.byType(LogViewerDialog), findsOneWidget);
    });

    testWidgets('checking for updates shows a not-yet-available dialog', (
      tester,
    ) async {
      await _open(tester);
      // The tile says it as well.
      expect(find.text('Noch nicht verfügbar'), findsOneWidget);

      await _tapAndSettle(tester, 'Nach Updates suchen');

      expect(find.text('Noch nicht verfügbar'), findsNWidgets(2));
      await _tapAndSettle(tester, 'Schließen');
      expect(find.text('Noch nicht verfügbar'), findsOneWidget);
    });

    testWidgets('restart runs immediately, without any confirmation', (
      tester,
    ) async {
      var restarted = false;
      await _open(tester, onRestart: () => restarted = true);

      await tester.tap(find.text('Neustart'));
      await tester.pump();

      expect(restarted, isTrue);
    });

    testWidgets('with less room, for example under a notice strip, the page '
        'scrolls instead of overflowing', (tester) async {
      await _open(tester);

      tester.view.physicalSize = const Size(1024, 330);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Version'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Version'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the version tile only shows, it does not react', (
      tester,
    ) async {
      await _open(tester);

      await tester.tap(find.text('Version'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      // Not set in a test build.
      expect(find.text('unknown'), findsOneWidget);
    });

    testWidgets('the version tile shows the version and the date, not the '
        'commit', (tester) async {
      AppVersion.initialize(
        version: '0.17.0',
        build: '0.17.0+git20261013160833.ba2e5787f662',
      );
      addTearDown(
        () => AppVersion.initialize(
          version: AppVersion.unknown,
          build: AppVersion.unknown,
        ),
      );
      await _open(tester);

      expect(find.text('0.17.0\n2026-10-13'), findsOneWidget);
      expect(find.textContaining('ba2e5787f662'), findsNothing);
      expect(find.textContaining('git2026'), findsNothing);
    });
  });

  group('Beenden asks the backend for the password (#51)', () {
    testWidgets('a wrong password does not exit and can be tried again', (
      tester,
    ) async {
      var exited = false;
      final store = FakeExitPasswordStore();
      await _open(tester, onExit: () => exited = true, store: store);

      await _tapAndSettle(tester, 'Beenden');
      expect(find.text('Passwort erforderlich'), findsOneWidget);
      await _type(tester, 'wrong');
      await _tapAndSettle(tester, 'Bestätigen');

      expect(store.verifies, ['wrong']);
      expect(find.text('Falsches Passwort'), findsOneWidget);
      expect(exited, isFalse);
      expect(find.text('Passwort erforderlich'), findsOneWidget);
      // The field is empty for the next try.
      expect(_fieldText(tester), isEmpty);

      await _type(tester, '4321');
      await _tapAndSettle(tester, 'Bestätigen');
      expect(exited, isTrue);
    });

    testWidgets('the right password exits and closes the dialog', (
      tester,
    ) async {
      var exited = false;
      final store = FakeExitPasswordStore(password: 'geheim');
      await _open(tester, onExit: () => exited = true, store: store);

      await _tapAndSettle(tester, 'Beenden');
      await _type(tester, 'geheim');
      await _tapAndSettle(tester, 'Bestätigen');

      expect(store.verifies, ['geheim']);
      expect(exited, isTrue);
      expect(find.text('Passwort erforderlich'), findsNothing);
    });

    testWidgets('the old built-in password is not accepted any more', (
      tester,
    ) async {
      var exited = false;
      final store = FakeExitPasswordStore(password: 'eigenes-passwort');
      await _open(tester, onExit: () => exited = true, store: store);

      await _tapAndSettle(tester, 'Beenden');
      await _type(tester, '4321');
      await _tapAndSettle(tester, 'Bestätigen');

      expect(exited, isFalse);
      expect(find.text('Falsches Passwort'), findsOneWidget);
    });

    testWidgets('cancelling does not exit and does not ask the backend', (
      tester,
    ) async {
      var exited = false;
      final store = FakeExitPasswordStore();
      await _open(tester, onExit: () => exited = true, store: store);

      await _tapAndSettle(tester, 'Beenden');
      await _tapAndSettle(tester, 'Abbrechen');

      expect(exited, isFalse);
      expect(store.verifies, isEmpty);
      expect(find.text('Passwort erforderlich'), findsNothing);
    });

    testWidgets('while the backend checks, it says so and cannot be pressed '
        'twice', (tester) async {
      var exited = false;
      final store = FakeExitPasswordStore()..gate = Completer<void>();
      await _open(tester, onExit: () => exited = true, store: store);
      await _tapAndSettle(tester, 'Beenden');
      await _type(tester, '4321');

      await tester.tap(find.text('Bestätigen'));
      await tester.pump();

      expect(find.text('Wird geprüft …'), findsOneWidget);
      await tester.tap(find.text('Bestätigen'), warnIfMissed: false);
      await tester.pump();
      expect(store.verifies, ['4321']);
      expect(exited, isFalse);

      store.gate?.complete();
      await tester.pumpAndSettle();
      expect(exited, isTrue);
    });

    testWidgets('a backend that is away: no exit, a hint, and another try '
        'works', (tester) async {
      var exited = false;
      final store = FakeExitPasswordStore()..verifyError = backendAway;
      await _open(tester, onExit: () => exited = true, store: store);

      await _tapAndSettle(tester, 'Beenden');
      await _type(tester, '4321');
      await _tapAndSettle(tester, 'Bestätigen');

      expect(exited, isFalse);
      expect(find.text('Passwort erforderlich'), findsOneWidget);
      expect(
        find.textContaining('kann gerade nicht geprüft werden'),
        findsOneWidget,
      );
      // The password was not wrong, so it stays for the next try.
      expect(_fieldText(tester), '4321');

      store.verifyError = null;
      await _tapAndSettle(tester, 'Bestätigen');
      expect(exited, isTrue);
    });

    testWidgets('without a backend nothing can exit', (tester) async {
      var exited = false;
      await _open(tester, onExit: () => exited = true);

      await _tapAndSettle(tester, 'Beenden');
      await _type(tester, '4321');
      await _tapAndSettle(tester, 'Bestätigen');

      expect(exited, isFalse);
      expect(
        find.textContaining('kann gerade nicht geprüft werden'),
        findsOneWidget,
      );
    });

    testWidgets('the dialog sits in the middle above the keyboard, with room '
        'at the top', (tester) async {
      await _open(tester, store: FakeExitPasswordStore());
      await _tapAndSettle(tester, 'Beenden');

      _expectAboveKeyboard(tester, 'exit dialog');
      final top = tester
          .getRect(
            find
                .descendant(
                  of: find.byType(AlertDialog),
                  matching: find.byType(Material),
                )
                .first,
          )
          .top;
      expect(top, greaterThanOrEqualTo(24));
    });

    testWidgets('the dialog keeps its size when a message comes', (
      tester,
    ) async {
      final store = FakeExitPasswordStore();
      await _open(tester, store: store);
      await _tapAndSettle(tester, 'Beenden');
      Rect dialog() => tester.getRect(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Material),
            )
            .first,
      );
      final before = dialog();

      await _type(tester, 'wrong');
      await _tapAndSettle(tester, 'Bestätigen');

      expect(find.text('Falsches Passwort'), findsOneWidget);
      expect(dialog(), before);
    });

    testWidgets('a wrong password leaves the keyboard open for the next try', (
      tester,
    ) async {
      await _onLinux(() async {
        await _open(tester, store: FakeExitPasswordStore());
        await _tapAndSettle(tester, 'Beenden');
        expect(_keyboardTop(tester), 308);

        await _type(tester, 'wrong');
        await _tapAndSettle(tester, 'Bestätigen');

        expect(find.text('Falsches Passwort'), findsOneWidget);
        expect(_keyboardTop(tester), 308);
      });
    });

    testWidgets('dialogs are lighter than the page behind them', (
      tester,
    ) async {
      await _open(tester, store: FakeExitPasswordStore());

      await _tapAndSettle(tester, 'Beenden');
      Color dialogColor() => tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(AlertDialog),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      expect(dialogColor(), AppColors.surfaceContainerHighest);
      expect(dialogColor(), isNot(AppColors.surface));

      // The same for a dialog that is none of the password dialogs.
      await _tapDialogButton(tester, 'Abbrechen');
      await _tapAndSettle(tester, 'Nach Updates suchen');
      expect(dialogColor(), AppColors.surfaceContainerHighest);
    });

    testWidgets('the password is hidden, and the eye shows it', (tester) async {
      await _open(tester, store: FakeExitPasswordStore());
      await _tapAndSettle(tester, 'Beenden');

      bool obscured() =>
          tester.widget<TextField>(find.byType(TextField)).obscureText;
      expect(obscured(), isTrue);

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();
      expect(obscured(), isFalse);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();
      expect(obscured(), isTrue);
    });
  });

  group('Passwort ändern (#51)', () {
    Future<void> openDialog(
      WidgetTester tester,
      FakeExitPasswordStore store,
    ) async {
      await _open(tester, store: store);
      await _tapAndSettle(tester, 'Passwort ändern');
    }

    // The tile and the dialog title carry the same words.
    Finder dialogTitle() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Passwort ändern'),
    );

    testWidgets('three steps change the password', (tester) async {
      final store = FakeExitPasswordStore();
      await openDialog(tester, store);

      expect(dialogTitle(), findsOneWidget);
      expect(
        find.text('Bitte geben Sie das aktuelle Passwort ein.'),
        findsOneWidget,
      );
      await _type(tester, '4321');
      await _tapAndSettle(tester, 'Weiter');
      expect(store.verifies, ['4321']);

      expect(
        find.text('Bitte geben Sie das neue Passwort ein (4 bis 64 Zeichen).'),
        findsOneWidget,
      );
      expect(_fieldText(tester), isEmpty);
      await _type(tester, 'neues-passwort');
      await _tapAndSettle(tester, 'Weiter');

      expect(
        find.text('Bitte wiederholen Sie das neue Passwort.'),
        findsOneWidget,
      );
      await _type(tester, 'neues-passwort');
      await _tapAndSettle(tester, 'Bestätigen');

      expect(store.changes, ['4321>neues-passwort']);
      expect(store.password, 'neues-passwort');
      expect(
        find.text('Das Passwort wurde erfolgreich geändert.'),
        findsOneWidget,
      );
      expect(find.byType(OnScreenTextField), findsNothing);

      await _tapDialogButton(tester, 'Fertig');
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('the keyboard stays open from step to step, and goes with the '
        'last one, which is centered on the whole display', (tester) async {
      await _onLinux(() async {
        final store = FakeExitPasswordStore();
        await openDialog(tester, store);
        expect(_keyboardTop(tester), 308);

        await _type(tester, '4321');
        await _tapAndSettle(tester, 'Weiter');
        expect(find.byType(OnScreenTextField), findsOneWidget);
        expect(_keyboardTop(tester), 308);

        await _type(tester, 'abcd');
        await _tapAndSettle(tester, 'Weiter');
        expect(_keyboardTop(tester), 308);

        // A wrong repeat comes back to the step with the keyboard still there.
        await _type(tester, 'abce');
        await _tapAndSettle(tester, 'Bestätigen');
        expect(find.textContaining('stimmen nicht überein'), findsOneWidget);
        expect(_keyboardTop(tester), 308);

        await _type(tester, 'abcd');
        await _tapAndSettle(tester, 'Weiter');
        await _type(tester, 'abcd');
        await _tapAndSettle(tester, 'Bestätigen');

        // Saved: no field any more, so no keyboard; the message is in the
        // middle of the display.
        expect(
          find.text('Das Passwort wurde erfolgreich geändert.'),
          findsOneWidget,
        );
        expect(_keyboardTop(tester), 600);
        expect(_dialogRect(tester).center.dy, closeTo(300, 2));
        expect(_dialogRect(tester).center.dx, closeTo(512, 2));
      });
    });

    testWidgets('a wrong current password leaves the keyboard open', (
      tester,
    ) async {
      await _onLinux(() async {
        await openDialog(tester, FakeExitPasswordStore());

        await _type(tester, 'wrong');
        await _tapAndSettle(tester, 'Weiter');

        expect(find.text('Falsches Passwort'), findsOneWidget);
        expect(_keyboardTop(tester), 308);
      });
    });

    testWidgets('the new password then opens the exit, the old one does not', (
      tester,
    ) async {
      var exited = false;
      final store = FakeExitPasswordStore();
      await _open(tester, onExit: () => exited = true, store: store);
      await _tapAndSettle(tester, 'Passwort ändern');
      await _type(tester, '4321');
      await _tapAndSettle(tester, 'Weiter');
      await _type(tester, 'abcd');
      await _tapAndSettle(tester, 'Weiter');
      await _type(tester, 'abcd');
      await _tapAndSettle(tester, 'Bestätigen');
      await _tapDialogButton(tester, 'Fertig');

      await _tapAndSettle(tester, 'Beenden');
      await _type(tester, '4321');
      await _tapAndSettle(tester, 'Bestätigen');
      expect(exited, isFalse);

      await _type(tester, 'abcd');
      await _tapAndSettle(tester, 'Bestätigen');
      expect(exited, isTrue);
    });

    testWidgets('a wrong current password stops at once, nothing is changed', (
      tester,
    ) async {
      final store = FakeExitPasswordStore();
      await openDialog(tester, store);

      await _type(tester, 'wrong');
      await _tapAndSettle(tester, 'Weiter');

      expect(find.text('Falsches Passwort'), findsOneWidget);
      expect(
        find.text('Bitte geben Sie das aktuelle Passwort ein.'),
        findsOneWidget,
      );
      expect(_fieldText(tester), isEmpty);
      expect(store.changes, isEmpty);
    });

    testWidgets('a new password of 3 or 65 characters is refused before the '
        'backend is asked', (tester) async {
      final store = FakeExitPasswordStore();
      await openDialog(tester, store);
      await _type(tester, '4321');
      await _tapAndSettle(tester, 'Weiter');

      await _type(tester, 'abc');
      await _tapAndSettle(tester, 'Weiter');
      expect(
        find.text('Das neue Passwort muss 4 bis 64 Zeichen lang sein.'),
        findsOneWidget,
      );
      expect(
        find.text('Bitte geben Sie das neue Passwort ein (4 bis 64 Zeichen).'),
        findsOneWidget,
      );

      await _type(tester, 'a' * 65);
      await _tapAndSettle(tester, 'Weiter');
      expect(
        find.text('Das neue Passwort muss 4 bis 64 Zeichen lang sein.'),
        findsOneWidget,
      );

      await _type(tester, 'a' * 64);
      await _tapAndSettle(tester, 'Weiter');
      expect(
        find.text('Bitte wiederholen Sie das neue Passwort.'),
        findsOneWidget,
      );
      expect(store.changes, isEmpty);
    });

    testWidgets('a repeat that differs goes back to the new password', (
      tester,
    ) async {
      final store = FakeExitPasswordStore();
      await openDialog(tester, store);
      await _type(tester, '4321');
      await _tapAndSettle(tester, 'Weiter');
      await _type(tester, 'abcd');
      await _tapAndSettle(tester, 'Weiter');

      await _type(tester, 'abce');
      await _tapAndSettle(tester, 'Bestätigen');

      expect(
        find.textContaining('Die Eingaben stimmen nicht überein'),
        findsOneWidget,
      );
      expect(
        find.text('Bitte geben Sie das neue Passwort ein (4 bis 64 Zeichen).'),
        findsOneWidget,
      );
      expect(store.changes, isEmpty);
    });

    testWidgets('the backend says the current password is wrong after all: '
        'back to the first step', (tester) async {
      final store = FakeExitPasswordStore();
      await openDialog(tester, store);
      await _type(tester, '4321');
      await _tapAndSettle(tester, 'Weiter');
      await _type(tester, 'abcd');
      await _tapAndSettle(tester, 'Weiter');
      // Changed elsewhere in the meantime.
      store.password = 'anders';
      await _type(tester, 'abcd');
      await _tapAndSettle(tester, 'Bestätigen');

      expect(find.text('Falsches Passwort'), findsOneWidget);
      expect(
        find.text('Bitte geben Sie das aktuelle Passwort ein.'),
        findsOneWidget,
      );
      expect(store.password, 'anders');
    });

    testWidgets('the backend refuses the new password: back to the new '
        'password', (tester) async {
      final store = FakeExitPasswordStore();
      await openDialog(tester, store);
      await _type(tester, '4321');
      await _tapAndSettle(tester, 'Weiter');
      await _type(tester, 'abcd');
      await _tapAndSettle(tester, 'Weiter');
      store.changeError = const ExitPasswordException(
        ExitPasswordFailure.rejected,
        'password must not contain control characters',
      );
      await _type(tester, 'abcd');
      await _tapAndSettle(tester, 'Bestätigen');

      expect(
        find.text('Das neue Passwort muss 4 bis 64 Zeichen lang sein.'),
        findsOneWidget,
      );
      // The English text of the backend is never shown.
      expect(find.textContaining('control characters'), findsNothing);
      expect(
        find.text('Bitte geben Sie das neue Passwort ein (4 bis 64 Zeichen).'),
        findsOneWidget,
      );
    });

    testWidgets('a backend that is away stays on the step, and another try '
        'works', (tester) async {
      final store = FakeExitPasswordStore()..verifyError = backendAway;
      await openDialog(tester, store);

      await _type(tester, '4321');
      await _tapAndSettle(tester, 'Weiter');
      expect(
        find.textContaining('kann gerade nicht geprüft werden'),
        findsOneWidget,
      );
      expect(
        find.text('Bitte geben Sie das aktuelle Passwort ein.'),
        findsOneWidget,
      );

      store.verifyError = null;
      await _tapAndSettle(tester, 'Weiter');
      expect(
        find.text('Bitte geben Sie das neue Passwort ein (4 bis 64 Zeichen).'),
        findsOneWidget,
      );

      await _type(tester, 'abcd');
      await _tapAndSettle(tester, 'Weiter');
      store.changeError = backendAway;
      await _type(tester, 'abcd');
      await _tapAndSettle(tester, 'Bestätigen');
      expect(
        find.textContaining('kann gerade nicht geprüft werden'),
        findsOneWidget,
      );
      expect(
        find.text('Bitte wiederholen Sie das neue Passwort.'),
        findsOneWidget,
      );

      await _tapAndSettle(tester, 'Bestätigen');
      expect(store.password, 'abcd');
      expect(
        find.text('Das Passwort wurde erfolgreich geändert.'),
        findsOneWidget,
      );
    });

    testWidgets('a backend that cannot save says so', (tester) async {
      final store = FakeExitPasswordStore();
      await openDialog(tester, store);
      await _type(tester, '4321');
      await _tapAndSettle(tester, 'Weiter');
      await _type(tester, 'abcd');
      await _tapAndSettle(tester, 'Weiter');
      store.changeError = const ExitPasswordException(
        ExitPasswordFailure.failed,
        'could not write the file',
      );
      await _type(tester, 'abcd');
      await _tapAndSettle(tester, 'Bestätigen');

      expect(
        find.text('Das Passwort konnte nicht gespeichert werden.'),
        findsOneWidget,
      );
      expect(store.password, '4321');
    });

    testWidgets('cancelling at any step changes nothing', (tester) async {
      final store = FakeExitPasswordStore();
      await openDialog(tester, store);
      await _type(tester, '4321');
      await _tapAndSettle(tester, 'Weiter');
      await _type(tester, 'abcd');
      await _tapAndSettle(tester, 'Weiter');

      await _tapAndSettle(tester, 'Abbrechen');

      expect(find.byType(AlertDialog), findsNothing);
      expect(store.changes, isEmpty);
      expect(store.password, '4321');
    });

    testWidgets('without a backend nothing can be changed', (tester) async {
      await _open(tester);
      await _tapAndSettle(tester, 'Passwort ändern');

      await _type(tester, '4321');
      await _tapAndSettle(tester, 'Weiter');

      expect(
        find.textContaining('kann gerade nicht geprüft werden'),
        findsOneWidget,
      );
      expect(
        find.text('Bitte geben Sie das aktuelle Passwort ein.'),
        findsOneWidget,
      );
    });
  });

  group('every language fits the page and the dialogs at 1024x600', () {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('${locale.languageCode}: tiles, exit dialog, change dialog', (
        tester,
      ) async {
        final store = FakeExitPasswordStore();
        await _open(tester, store: store, locale: locale);
        expect(tester.takeException(), isNull);

        // The exit dialog with its longest message, above the keyboard.
        await tester.tap(find.byIcon(Icons.power_settings_new));
        await tester.pumpAndSettle();
        store.verifyError = backendAway;
        await _type(tester, 'x');
        await tester.tap(find.byType(TextButton).last);
        await tester.pumpAndSettle();
        _expectAboveKeyboard(tester, 'exit dialog with the message');
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(TextButton).first);
        await tester.pumpAndSettle();

        // The change dialog, step by step, with the longest problem texts.
        await tester.tap(find.byIcon(Icons.password));
        await tester.pumpAndSettle();
        _expectAboveKeyboard(tester, 'change dialog, step 1');
        store.verifyError = backendAway;
        await _type(tester, 'x');
        await tester.tap(find.byType(TextButton).last);
        await tester.pumpAndSettle();
        _expectAboveKeyboard(tester, 'step 1 with the message');
        store.verifyError = null;
        await _type(tester, '4321');
        await tester.tap(find.byType(TextButton).last);
        await tester.pumpAndSettle();
        await _type(tester, 'abc');
        await tester.tap(find.byType(TextButton).last);
        await tester.pumpAndSettle();
        _expectAboveKeyboard(tester, 'step 2 with the rules message');
        await _type(tester, 'abcd');
        await tester.tap(find.byType(TextButton).last);
        await tester.pumpAndSettle();
        await _type(tester, 'abce');
        await tester.tap(find.byType(TextButton).last);
        await tester.pumpAndSettle();
        _expectAboveKeyboard(tester, 'step 2 after a mismatch');
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// The dialog must end above the keyboard, or it would cover its own buttons,
/// and sit in the middle of the space above it: not stuck to the top edge.
void _expectAboveKeyboard(WidgetTester tester, String where) {
  final dialog = tester.getRect(
    find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Material),
        )
        .first,
  );
  final keyboardTop = tester.getTopLeft(find.byType(KeyboardPanel)).dy;
  final above = dialog.top;
  final below = keyboardTop - dialog.bottom;
  expect(
    below,
    greaterThanOrEqualTo(0),
    reason: '$where: dialog ${dialog.bottom} vs keyboard $keyboardTop',
  );
  expect(
    above,
    greaterThanOrEqualTo(12),
    reason: '$where: dialog top ${dialog.top}',
  );
  // The same room above and below, as far as the content allows.
  expect(
    (above - 12 - below).abs(),
    lessThanOrEqualTo(1),
    reason: '$where: above ${above - 12}, below $below',
  );
}
