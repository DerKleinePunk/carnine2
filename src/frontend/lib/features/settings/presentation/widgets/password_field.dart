import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_overlay.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// A password field on the on-screen keyboard: hidden as dots, with an eye
/// that shows what was typed. Touch typing 4 to 64 characters goes wrong
/// easily, so the user can look.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.hintText,
    this.autofocus = true,
    this.onSubmitted,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final eyeLabel = l10n.text(
      _visible
          ? AppTextKey.settingsExitPasswordHide
          : AppTextKey.settingsExitPasswordShow,
    );

    return OnScreenTextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      obscureText: !_visible,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      semanticLabel: widget.hintText,
      hintText: widget.hintText,
      // The eye must not take the focus, or the keyboard would close.
      suffixIcon: ExcludeFocus(
        child: IconButton(
          tooltip: eyeLabel,
          onPressed: () => setState(() => _visible = !_visible),
          icon: Icon(
            _visible ? Icons.visibility_off : Icons.visibility,
            color: AppColors.onSurfaceVariant,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// The frame of both password dialogs. The on-screen keyboard opens at once
/// and takes the lower [keyboardPanelHeight] of the display, so the dialog is
/// centered in the space above it: neither stuck to the top edge nor behind
/// the keyboard, where its buttons could not be tapped. Without a field, when
/// [keyboardOpen] is `false`, it is centered on the whole display.
class PasswordDialogFrame extends StatelessWidget {
  const PasswordDialogFrame({
    required this.title,
    required this.content,
    required this.actions,
    this.keyboardOpen = true,
    super.key,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final bool keyboardOpen;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      alignment: Alignment.center,
      // A text longer than expected scrolls instead of overflowing.
      scrollable: true,
      insetPadding: EdgeInsets.fromLTRB(
        40,
        12,
        40,
        keyboardOpen ? keyboardPanelHeight : 12,
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      title: Text(title),
      content: content,
      // A tap on a button is not "outside" the field: on Linux the field would
      // lose the focus, and with it the keyboard, after every step.
      actions: [
        for (final action in actions) TextFieldTapRegion(child: action),
      ],
    );
  }
}

/// The line under the field for "Wird geprüft …", "Falsches Passwort" and the
/// like. It keeps room for two lines even when empty, so the dialog does not
/// jump when a message comes and goes.
class PasswordMessage extends StatelessWidget {
  const PasswordMessage({this.text, this.isError = true, super.key});

  /// `null` for no message.
  final String? text;

  /// Red for a problem, grey for "busy".
  final bool isError;

  /// Two lines of the 12 px text.
  static const double reservedHeight = 36;

  @override
  Widget build(BuildContext context) {
    final message = text;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: reservedHeight),
      child: Align(
        alignment: Alignment.topLeft,
        child: message == null
            ? null
            : Text(
                message,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: isError ? AppColors.error : AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }
}
