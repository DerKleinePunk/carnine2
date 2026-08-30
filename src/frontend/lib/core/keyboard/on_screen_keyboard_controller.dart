import 'package:flutter/material.dart';

import 'keyboard_layout.dart';

/// Ambient state for the app-wide on-screen keyboard: which field is
/// currently bound to it, which layer is showing, and the text-mutation
/// logic every key ultimately calls.
///
/// Writes go directly into the bound [TextEditingController] - the keyboard
/// never touches Flutter's platform text-input/IME channel, since the
/// target hardware (flutter-pi on a bare Debian rootfs) has no system
/// keyboard to coordinate with in the first place.
class OnScreenKeyboardController extends ChangeNotifier {
  TextEditingController? _activeController;
  FocusNode? _activeFocusNode;
  ValueChanged<String>? _onSubmitted;
  int? _activeMaxLength;

  KeyboardLayer _layer = KeyboardLayer.letters;
  bool _isShifted = false;

  TextEditingController? get activeController => _activeController;
  FocusNode? get activeFocusNode => _activeFocusNode;
  KeyboardLayer get layer => _layer;
  bool get isShifted => _isShifted;
  bool get isOpen => _activeController != null;

  /// Binds the keyboard to [controller]. Called by [OnScreenTextField] when
  /// its [FocusNode] gains focus.
  void requestKeyboard({
    required TextEditingController controller,
    required FocusNode focusNode,
    ValueChanged<String>? onSubmitted,
    int? maxLength,
  }) {
    if (_activeController == controller) {
      return;
    }

    _activeController = controller;
    _activeFocusNode = focusNode;
    _onSubmitted = onSubmitted;
    _activeMaxLength = maxLength;
    _layer = KeyboardLayer.letters;
    // Auto-capitalize the first character of a fresh entry, matching
    // standard keyboard convention - but not on refocusing a field that
    // already has content, where the user is continuing mid-text.
    _isShifted = controller.text.isEmpty;
    notifyListeners();
  }

  /// Unbinds the keyboard, but only if [controller] is still the active one.
  ///
  /// A no-op otherwise: when focus moves directly from field A to field B,
  /// B's focus listener fires and reassigns the active controller before
  /// A's "focus lost" listener fires its own release call - without this
  /// guard, A's stale release would tear down the keyboard B just opened.
  void releaseKeyboard(TextEditingController controller) {
    if (_activeController != controller) {
      return;
    }

    close();
  }

  /// Reports the current text as submitted, then closes.
  void submit() {
    _onSubmitted?.call(_activeController?.text ?? '');
    close();
  }

  void close() {
    if (_activeController == null) {
      return;
    }

    _activeFocusNode?.unfocus();
    _activeController = null;
    _activeFocusNode = null;
    _onSubmitted = null;
    _activeMaxLength = null;
    notifyListeners();
  }

  void toggleLayer() {
    _layer = _layer == KeyboardLayer.letters
        ? KeyboardLayer.numbersSymbols
        : KeyboardLayer.letters;
    notifyListeners();
  }

  void toggleShift() {
    _isShifted = !_isShifted;
    notifyListeners();
  }

  /// Inserts [char] at the current selection, replacing it if non-collapsed.
  /// Applies a one-shot capitalization if shift is active, then clears it.
  ///
  /// Enforces [OnScreenTextField.maxLength] itself: writes go straight into
  /// the [TextEditingController], bypassing the `inputFormatters`/
  /// `LengthLimitingTextInputFormatter` pipeline `TextField.maxLength`
  /// normally relies on - that pipeline only runs for edits that arrive
  /// through the platform text-input connection, which this keyboard never
  /// uses.
  void insertCharacter(String char) {
    final controller = _activeController;
    if (controller == null) {
      return;
    }

    final value = controller.value;
    final selection = _normalizedSelection(value);
    final inserted = _isShifted ? char.toUpperCase() : char;

    final maxLength = _activeMaxLength;
    if (maxLength != null) {
      // selection.start/end are UTF-16 code-unit offsets, not grapheme
      // indices - substring with those first, then count graphemes on the
      // result, matching how backspace() already handles this conversion.
      final selectedText = value.text.substring(selection.start, selection.end);
      final resultingLength = value.text.characters.length -
          selectedText.characters.length +
          inserted.characters.length;
      if (resultingLength > maxLength) {
        return;
      }
    }

    controller.value = value.replaced(selection, inserted);

    if (_isShifted) {
      _isShifted = false;
      notifyListeners();
    }
  }

  /// Deletes the current selection, or one grapheme before the cursor.
  void backspace() {
    final controller = _activeController;
    if (controller == null) {
      return;
    }

    final value = controller.value;
    final selection = _normalizedSelection(value);

    if (!selection.isCollapsed) {
      controller.value = value.replaced(selection, '');
      return;
    }

    if (selection.start == 0) {
      return;
    }

    final beforeCursor = value.text.substring(0, selection.start);
    final afterCursor = value.text.substring(selection.start);
    final characters = beforeCursor.characters;
    final withoutLastGrapheme = characters.skipLast(1).toString();

    controller.value = TextEditingValue(
      text: withoutLastGrapheme + afterCursor,
      selection: TextSelection.collapsed(offset: withoutLastGrapheme.length),
    );
  }

  TextSelection _normalizedSelection(TextEditingValue value) {
    if (value.selection.isValid) {
      return value.selection;
    }

    return TextSelection.collapsed(offset: value.text.length);
  }
}
