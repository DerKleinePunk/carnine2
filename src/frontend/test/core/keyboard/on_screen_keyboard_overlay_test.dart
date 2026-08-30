import 'package:carnine_frontend/core/keyboard/keyboard_panel.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_controller.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_overlay.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_scope.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const double _screenHeight = 600;

Widget _harness({
  required OnScreenKeyboardController keyboard,
  required TextEditingController field,
  ValueChanged<String>? onSubmitted,
}) {
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
      controller: keyboard,
      child: Stack(
        children: [child!, OnScreenKeyboardOverlay(controller: keyboard)],
      ),
    ),
    home: Scaffold(
      body: OnScreenTextField(
        controller: field,
        semanticLabel: 'field',
        onSubmitted: onSubmitted,
      ),
    ),
  );
}

void main() {
  testWidgets('the panel slides in on focus and back out on Fertig',
      (tester) async {
    tester.view.physicalSize = const Size(1024, _screenHeight);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final keyboard = OnScreenKeyboardController();
    final field = TextEditingController();
    String? submitted;
    addTearDown(keyboard.dispose);
    addTearDown(field.dispose);

    await tester.pumpWidget(_harness(
      keyboard: keyboard,
      field: field,
      onSubmitted: (value) => submitted = value,
    ));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(KeyboardPanel)).dy,
        greaterThanOrEqualTo(_screenHeight));

    await tester.tap(find.byType(OnScreenTextField));
    await tester.pumpAndSettle();

    expect(keyboard.isOpen, isTrue);
    expect(tester.getTopLeft(find.byType(KeyboardPanel)).dy,
        lessThan(_screenHeight));

    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();

    expect(keyboard.isOpen, isFalse);
    expect(submitted, '');
    expect(tester.getTopLeft(find.byType(KeyboardPanel)).dy,
        greaterThanOrEqualTo(_screenHeight));
  });
}
