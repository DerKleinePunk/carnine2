import 'package:carnine_frontend/core/keyboard/keyboard_key.dart';
import 'package:carnine_frontend/core/keyboard/keyboard_layout.dart';
import 'package:carnine_frontend/core/keyboard/keyboard_panel.dart'
    show keyRowHeight;
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_controller.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_overlay.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_scope.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required OnScreenKeyboardController keyboard,
  required TextEditingController field,
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
      body: Column(
        children: [
          OnScreenTextField(controller: field, semanticLabel: 'field'),
          // Fixed, modest height: large enough to tap reliably, small
          // enough to stay clear of the keyboard panel's own region at the
          // bottom of the 600px test viewport when it's open.
          const SizedBox(
            height: 100,
            child: ColoredBox(
              key: ValueKey('elsewhere'),
              color: Colors.transparent,
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  late OnScreenKeyboardController keyboard;
  late TextEditingController field;

  setUp(() {
    keyboard = OnScreenKeyboardController();
    field = TextEditingController();
  });

  tearDown(() {
    keyboard.dispose();
    field.dispose();
  });

  Future<void> openKeyboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(keyboard: keyboard, field: field));
    await tester.pump();
    await tester.tap(find.byType(OnScreenTextField));
    await tester.pumpAndSettle();

    // A fresh empty field defaults to shift-on (auto-capitalize the first
    // letter - see the dedicated test below). Most tests here aren't about
    // that, so start every other test from a known, lowercase baseline.
    if (keyboard.isShifted) {
      keyboard.toggleShift();
      await tester.pump();
    }
  }

  testWidgets('letter keys append to the bound controller', (tester) async {
    await openKeyboard(tester);

    await tester.tap(find.text('h'));
    await tester.tap(find.text('i'));
    await tester.pump();

    expect(field.text, 'hi');
  });

  testWidgets(
      'on a desktop platform, tapping a key does not let the field\'s '
      'default tap-outside-unfocus close the keyboard before the tap '
      'registers (regression: keys silently did nothing on Linux/macOS/'
      'Windows, where TextField unfocuses on any outside tap by default - '
      'the keyboard panel lives in a separate part of the tree, so every '
      'key tap counted as "outside")', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    // Reset synchronously before this callback returns: the framework's
    // debugAssertAllFoundationVarsUnset check runs immediately after this
    // function completes, before any tearDown()/addTearDown() callback -
    // those fire too late to satisfy it.
    try {
      await openKeyboard(tester);

      await tester.tap(find.text('h'));
      await tester.tap(find.text('i'));
      await tester.pump();

      expect(field.text, 'hi');
      expect(keyboard.isOpen, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
      'on a desktop platform, tapping neither the field nor the keyboard '
      'closes it, and refocusing the field reopens it', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await openKeyboard(tester);
      expect(keyboard.isOpen, isTrue);

      await tester.tap(find.byKey(const ValueKey('elsewhere')));
      await tester.pumpAndSettle();

      expect(keyboard.isOpen, isFalse);

      await tester.tap(find.byType(OnScreenTextField));
      await tester.pumpAndSettle();

      expect(keyboard.isOpen, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the numbers layer inserts digits after toggling',
      (tester) async {
    await openKeyboard(tester);

    await tester.tap(find.text('123'));
    await tester.pump();
    await tester.tap(find.text('7'));
    await tester.pump();

    expect(field.text, '7');
  });

  testWidgets('backspace removes the last character', (tester) async {
    await openKeyboard(tester);
    field.text = 'hi';
    field.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();

    expect(field.text, 'h');
  });

  testWidgets('holding backspace deletes multiple characters', (tester) async {
    await openKeyboard(tester);
    field.text = 'hello';
    field.selection = const TextSelection.collapsed(offset: 5);
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.backspace_outlined)),
    );
    // Deletes immediately on press-down.
    await tester.pump();
    expect(field.text, 'hell');

    // The hold delay elapses, starting the repeat timer; each further
    // repeat interval deletes one more character.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 80));

    expect(field.text, 'h');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('releasing backspace stops the repeat', (tester) async {
    await openKeyboard(tester);
    field.text = 'hello';
    field.selection = const TextSelection.collapsed(offset: 5);
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.backspace_outlined)),
    );
    await tester.pump();
    // Reach the repeat phase, then release before it deletes everything.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 80));
    await gesture.up();
    final textAtRelease = field.text;

    // No further deletions after release, even though more time passes.
    await tester.pump(const Duration(seconds: 1));

    expect(field.text, textAtRelease);
    expect(field.text, isNotEmpty);
  });

  testWidgets('space inserts a blank character', (tester) async {
    await openKeyboard(tester);
    final spaceKey = find.byWidgetPredicate(
      (widget) => widget is KeyboardKey && widget.entry is SpaceKey,
    );

    await tester.tap(find.text('h'));
    await tester.tap(find.text('i'));
    await tester.tap(spaceKey);
    await tester.pump();

    expect(field.text, 'hi ');
  });

  testWidgets('shift capitalizes exactly the next letter', (tester) async {
    await openKeyboard(tester);

    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.tap(find.text('A'));
    await tester.pump();
    await tester.tap(find.text('b'));
    await tester.pump();

    expect(field.text, 'Ab');
  });

  testWidgets(
      'focusing a fresh empty field auto-capitalizes exactly the first '
      'letter, without any manual shift toggle', (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(keyboard: keyboard, field: field));
    await tester.pump();
    await tester.tap(find.byType(OnScreenTextField));
    await tester.pumpAndSettle();

    // No shift tap here - 'A' must already be showing by default.
    await tester.tap(find.text('A'));
    await tester.pump();
    await tester.tap(find.text('b'));
    await tester.pump();

    expect(field.text, 'Ab');
  });

  testWidgets(
      'long-pressing a single-row diacritic key and dragging one key-width '
      'right commits the next alternate', (tester) async {
    await openKeyboard(tester);

    // 'y' has only one diacritic (ý) - its popup never wraps, so this
    // isolates plain single-row horizontal dragging.
    final yFinder = find.text('y');
    final keyRect = tester.getRect(
      find.ancestor(of: yFinder, matching: find.byType(KeyboardKey)),
    );
    final startCenter = tester.getCenter(yFinder);

    final gesture = await tester.startGesture(startCenter);
    await tester.pump(kLongPressTimeout + kPressTimeout);
    await gesture.moveBy(Offset(keyRect.width, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(field.text, 'ý');
  });

  testWidgets(
      'a diacritic popup wide enough to run off-screen wraps to a second '
      'row instead of overflowing (regression: it used to render as one '
      'row and extend past the right edge for a key like "o" near the '
      'edge)', (tester) async {
    await openKeyboard(tester);

    // 'o' has 7 diacritics (8 alternates incl. the base) - wide enough to
    // need wrapping at 4 columns per row: [o,ò,ó,ô] on top, [ö,õ,ø,ő]
    // closest to the key.
    final oFinder = find.text('o');
    final popupWidth = 4 *
        tester
            .getRect(
                find.ancestor(of: oFinder, matching: find.byType(KeyboardKey)))
            .width;
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;

    // tester.longPress() releases immediately (down+wait+up in one call),
    // which would close the popup before it could be inspected - hold the
    // gesture open instead, matching the drag tests below.
    final gesture = await tester.startGesture(tester.getCenter(oFinder));
    await tester.pump(kLongPressTimeout + kPressTimeout);

    final popupRect = tester.getRect(find.byType(Wrap));
    expect(popupRect.width, lessThanOrEqualTo(popupWidth + 1));
    expect(popupRect.right, lessThanOrEqualTo(screenWidth));

    // Release without dragging - lands back on the base letter.
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'dragging horizontally only stays on the row closest to the key; '
      'dragging up into the wrapped row reaches the alternates above it',
      (tester) async {
    await openKeyboard(tester);

    final oFinder = find.text('o');
    final keyRect = tester.getRect(
      find.ancestor(of: oFinder, matching: find.byType(KeyboardKey)),
    );
    final startCenter = tester.getCenter(oFinder);

    // Horizontal-only drag: stays on the bottom row [ö,õ,ø,ő] - one
    // key-width right lands on its second entry, õ.
    final horizontalGesture = await tester.startGesture(startCenter);
    await tester.pump(kLongPressTimeout + kPressTimeout);
    await horizontalGesture.moveBy(Offset(keyRect.width, 0));
    await tester.pump();
    await horizontalGesture.up();
    await tester.pumpAndSettle();

    expect(field.text, 'õ');

    // Drag up past a full row height and one key-width right: reaches the
    // top row [o,ò,ó,ô]'s second entry, ò.
    final verticalGesture = await tester.startGesture(startCenter);
    await tester.pump(kLongPressTimeout + kPressTimeout);
    await verticalGesture.moveBy(Offset(keyRect.width, -keyRowHeight * 1.5));
    await tester.pump();
    await verticalGesture.up();
    await tester.pumpAndSettle();

    expect(field.text, 'õò');
  });

  testWidgets('a plain tap on a diacritic key still inserts the base letter',
      (tester) async {
    await openKeyboard(tester);

    await tester.tap(find.text('a'));
    await tester.pump();

    expect(field.text, 'a');
  });
}
