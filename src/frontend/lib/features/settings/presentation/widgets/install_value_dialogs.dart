import 'package:carnine_frontend/core/keyboard/keyboard_layout.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/features/settings/data/install_values_store.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/password_field.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/settings_choice_button.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// A number or a text of the expert page, typed on the on-screen keyboard
/// (#207): numbers open on the digits. Resolves to the new text, `null` on
/// cancel. A number outside its range is not taken.
Future<String?> showInstallValueDialog(
  BuildContext context, {
  required InstallValue value,
  required String current,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _InstallValueDialog(value: value, current: current),
  );
}

/// One of many choices (more than fit in a row), as a list. Resolves to the
/// chosen value, `null` on cancel.
Future<String?> showInstallChoiceDialog(
  BuildContext context, {
  required String title,
  required List<InstallValueChoice> choices,
  required String selected,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final choice in choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SettingsChoiceButton(
                  label: choice.label,
                  isSelected: choice.value == selected,
                  wraps: true,
                  onTap: () => Navigator.of(dialogContext).pop(choice.value),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.text(AppTextKey.settingsExitPasswordCancelAction)),
        ),
      ],
    ),
  );
}

class _InstallValueDialog extends StatefulWidget {
  const _InstallValueDialog({required this.value, required this.current});

  final InstallValue value;
  final String current;

  @override
  State<_InstallValueDialog> createState() => _InstallValueDialogState();
}

class _InstallValueDialogState extends State<_InstallValueDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.current,
  );
  bool _invalid = false;

  bool get _isNumber => widget.value.kind == InstallValueKind.integer;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// A number must be whole and in range; a text is held to its length by
  /// the keyboard already.
  bool _isValid(String text) {
    if (!_isNumber) {
      return true;
    }
    final number = int.tryParse(text);
    return number != null &&
        number >= widget.value.min &&
        number <= widget.value.max;
  }

  void _apply() {
    final text = _text.text.trim();
    if (!_isValid(text)) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = widget.value;
    final maxLength = value.maxLength > 0 ? value.maxLength : null;

    return PasswordDialogFrame(
      title: value.label,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OnScreenTextField(
              controller: _text,
              semanticLabel: value.label,
              autofocus: true,
              maxLength: _isNumber ? null : maxLength,
              keyboardLayer: _isNumber
                  ? KeyboardLayer.numbersSymbols
                  : KeyboardLayer.letters,
              onChanged: (_) {
                if (_invalid) {
                  setState(() => _invalid = false);
                }
              },
              onSubmitted: (_) => _apply(),
            ),
            const SizedBox(height: 8),
            PasswordMessage(
              text: _invalid
                  ? l10n.expertsOutOfRange(value.min, value.max)
                  : _hint(l10n, maxLength),
              isError: _invalid,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.text(AppTextKey.settingsExitPasswordCancelAction)),
        ),
        TextButton(
          onPressed: _apply,
          child: Text(l10n.text(AppTextKey.settingsExpertsApply)),
        ),
      ],
    );
  }

  String? _hint(AppLocalizations l10n, int? maxLength) {
    final value = widget.value;
    if (_isNumber) {
      final unit = value.unit.isEmpty ? '' : ' ${value.unit}';
      return '${l10n.expertsRange(value.min, value.max)}$unit';
    }
    return maxLength == null ? null : l10n.expertsMaxLength(maxLength);
  }
}
