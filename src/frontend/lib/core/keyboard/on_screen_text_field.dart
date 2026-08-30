import 'dart:async';

import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

import 'on_screen_keyboard_controller.dart';
import 'on_screen_keyboard_scope.dart';

/// Reusable text-entry field bound to the app-wide on-screen keyboard.
///
/// Renders like a normal Material text field but never opens Flutter's
/// platform text-input/IME channel (`readOnly: true`) - on focus it
/// registers [controller] with the ambient [OnScreenKeyboardScope], and the
/// root-mounted keyboard panel writes into it directly. `controller` stays
/// owned by the caller, exactly like a bare [TextField].
class OnScreenTextField extends StatefulWidget {
  const OnScreenTextField({
    required this.controller,
    required this.semanticLabel,
    this.hintText,
    this.autofocus = false,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    super.key,
  });

  final TextEditingController controller;
  final String semanticLabel;
  final String? hintText;
  final bool autofocus;

  /// Enforced by the on-screen keyboard itself (see
  /// [OnScreenKeyboardController.insertCharacter]), not by [TextField]'s own
  /// `inputFormatters` pipeline - this field never goes through that. Also
  /// passed to [TextField] so its standard "x/maxLength" counter still
  /// shows.
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  @override
  State<OnScreenTextField> createState() => _OnScreenTextFieldState();
}

class _OnScreenTextFieldState extends State<OnScreenTextField> {
  late final FocusNode _focusNode = FocusNode()
    ..addListener(_handleFocusChange);

  // Cached in didChangeDependencies(), not looked up in dispose(): by then
  // this element is unmounting and InheritedWidget lookups are no longer
  // valid on its context.
  OnScreenKeyboardController? _keyboardController;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChange);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _keyboardController = OnScreenKeyboardScope.of(context);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);

    final keyboardController = _keyboardController;
    final fieldController = widget.controller;
    if (keyboardController != null) {
      // Deferred to a microtask: this field can be disposed as part of the
      // very frame that's tearing down its own subtree (e.g. submitting and
      // navigating away in one step). Calling notifyListeners() -
      // releaseKeyboard's close() does, to slide the panel away - while the
      // framework is still finalizing that frame is illegal ("widget tree
      // was locked"). By the next microtask the frame is done and it's safe.
      scheduleMicrotask(
        () => keyboardController.releaseKeyboard(fieldController),
      );
    }

    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleTextChange() {
    widget.onChanged?.call(widget.controller.text);
  }

  void _handleFocusChange() {
    final scope = _keyboardController;
    if (scope == null) {
      return;
    }

    if (_focusNode.hasFocus) {
      scope.requestKeyboard(
        controller: widget.controller,
        focusNode: _focusNode,
        onSubmitted: widget.onSubmitted,
        maxLength: widget.maxLength,
      );
    } else {
      scope.releaseKeyboard(widget.controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: widget.semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          readOnly: true,
          showCursor: true,
          // Deliberately using TextField's default onTapOutside (desktop
          // platforms unfocus on any outside tap) rather than suppressing
          // it: that's exactly what should close the keyboard when the user
          // taps elsewhere on screen. It does NOT fire for taps on the
          // keyboard panel itself, because KeyboardPanel joins the same
          // TextFieldTapRegion group (see keyboard_panel.dart) - so a key
          // tap is "inside" this field's region, not outside it.
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onSurface),
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            hintText: widget.hintText,
            hintStyle: AppTextStyles.bodyLarge
                .copyWith(color: AppColors.onSurfaceVariant),
            counterStyle: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
            ),
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon,
          ),
        ),
      ),
    );
  }
}
