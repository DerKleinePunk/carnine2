import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_controller.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_overlay.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_scope.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/features/settings/presentation/models/settings_option_item.dart';
import 'package:carnine_frontend/features/settings/presentation/settings_content.dart';
import 'package:carnine_frontend/features/settings/presentation/settings_controller.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounts [SettingsContent] with the diagnostics page already open, and
/// injected onRestart/onExit fakes - the real [AppWindow] actions call
/// `exit(0)`, which would kill the test process.
Widget _harness({
  required VoidCallback onRestart,
  required VoidCallback onExit,
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
    locale: const Locale('de'),
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
}
