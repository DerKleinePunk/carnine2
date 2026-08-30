import 'package:carnine_frontend/core/keyboard/keyboard_layout.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late OnScreenKeyboardController keyboard;
  late TextEditingController field;
  late FocusNode focusNode;

  setUp(() {
    keyboard = OnScreenKeyboardController();
    field = TextEditingController();
    focusNode = FocusNode();
  });

  tearDown(() {
    keyboard.dispose();
    field.dispose();
    focusNode.dispose();
  });

  test('insertCharacter inserts at the cursor', () {
    field.text = 'helo';
    field.selection = const TextSelection.collapsed(offset: 3);
    keyboard.requestKeyboard(controller: field, focusNode: focusNode);

    keyboard.insertCharacter('l');

    expect(field.text, 'hello');
    expect(field.selection, const TextSelection.collapsed(offset: 4));
  });

  test('insertCharacter replaces a non-collapsed selection', () {
    field.text = 'hxllo';
    field.selection = const TextSelection(baseOffset: 1, extentOffset: 2);
    keyboard.requestKeyboard(controller: field, focusNode: focusNode);

    keyboard.insertCharacter('e');

    expect(field.text, 'hello');
  });

  test('backspace at offset 0 is a no-op', () {
    field.text = 'hello';
    field.selection = const TextSelection.collapsed(offset: 0);
    keyboard.requestKeyboard(controller: field, focusNode: focusNode);

    keyboard.backspace();

    expect(field.text, 'hello');
  });

  test('backspace deletes a non-collapsed selection', () {
    field.text = 'hexlo';
    field.selection = const TextSelection(baseOffset: 2, extentOffset: 3);
    keyboard.requestKeyboard(controller: field, focusNode: focusNode);

    keyboard.backspace();

    expect(field.text, 'helo');
  });

  test('backspace at the end removes the last character', () {
    field.text = 'hello';
    field.selection = const TextSelection.collapsed(offset: 5);
    keyboard.requestKeyboard(controller: field, focusNode: focusNode);

    keyboard.backspace();

    expect(field.text, 'hell');
    expect(field.selection, const TextSelection.collapsed(offset: 4));
  });

  test('toggleLayer flips and notifies', () {
    keyboard.requestKeyboard(controller: field, focusNode: focusNode);
    expect(keyboard.layer, KeyboardLayer.letters);

    var notified = false;
    keyboard.addListener(() => notified = true);
    keyboard.toggleLayer();

    expect(keyboard.layer, KeyboardLayer.numbersSymbols);
    expect(notified, isTrue);
  });

  test(
      'shift defaults on for an empty field, capitalizing exactly the '
      'first inserted character', () {
    field.text = '';
    field.selection = const TextSelection.collapsed(offset: 0);
    keyboard.requestKeyboard(controller: field, focusNode: focusNode);

    expect(keyboard.isShifted, isTrue);

    keyboard.insertCharacter('a');
    keyboard.insertCharacter('b');

    expect(field.text, 'Ab');
    expect(keyboard.isShifted, isFalse);
  });

  test(
      'shift defaults off when reopening on a field that already has '
      'text - the user is continuing mid-entry, not starting fresh', () {
    field.text = 'Drive';
    field.selection = const TextSelection.collapsed(offset: 5);
    keyboard.requestKeyboard(controller: field, focusNode: focusNode);

    expect(keyboard.isShifted, isFalse);
  });

  test('shift can still be toggled manually to capitalize a later character',
      () {
    field.text = 'Drive';
    field.selection = const TextSelection.collapsed(offset: 5);
    keyboard.requestKeyboard(controller: field, focusNode: focusNode);

    keyboard.toggleShift();
    keyboard.insertCharacter('x');

    expect(field.text, 'DriveX');
    expect(keyboard.isShifted, isFalse);
  });

  test(
      'releaseKeyboard is a no-op for a controller that is no longer active '
      '(focus already moved to a second field)', () {
    final secondField = TextEditingController();
    final secondFocusNode = FocusNode();
    addTearDown(secondField.dispose);
    addTearDown(secondFocusNode.dispose);

    keyboard.requestKeyboard(controller: field, focusNode: focusNode);
    keyboard.requestKeyboard(
        controller: secondField, focusNode: secondFocusNode);

    keyboard.releaseKeyboard(field);

    expect(keyboard.isOpen, isTrue);
    expect(keyboard.activeController, secondField);
  });

  test('insertCharacter does nothing once maxLength is reached', () {
    field.text = 'a' * 40;
    field.selection = const TextSelection.collapsed(offset: 40);
    keyboard.requestKeyboard(
      controller: field,
      focusNode: focusNode,
      maxLength: 40,
    );

    keyboard.insertCharacter('b');

    expect(field.text, 'a' * 40);
  });

  test(
      'insertCharacter still allows a replacement that keeps the result '
      'within maxLength', () {
    field.text = 'a' * 40;
    field.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
    keyboard.requestKeyboard(
      controller: field,
      focusNode: focusNode,
      maxLength: 40,
    );

    keyboard.insertCharacter('b');

    expect(field.text, 'b${'a' * 35}');
  });

  test('insertCharacter has no limit when maxLength is not given', () {
    field.text = 'a' * 100;
    field.selection = const TextSelection.collapsed(offset: 100);
    keyboard.requestKeyboard(controller: field, focusNode: focusNode);

    keyboard.insertCharacter('b');

    expect(field.text, '${'a' * 100}b');
  });

  test('submit reports the current text then closes', () {
    field.text = 'Drive';
    String? submitted;
    keyboard.requestKeyboard(
      controller: field,
      focusNode: focusNode,
      onSubmitted: (value) => submitted = value,
    );

    keyboard.submit();

    expect(submitted, 'Drive');
    expect(keyboard.isOpen, isFalse);
  });
}
