import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Confirms exit with a password prompt before [AppWindow.exitApplication]
/// runs.
///
/// Mockup only: the accepted password is hardcoded, there is no real
/// authentication backend yet - see [_mockPassword].
class ExitPasswordDialog extends StatefulWidget {
  const ExitPasswordDialog({super.key});

  // TODO(auth): replace with a real credential check once one exists.
  static const String _mockPassword = '4321';

  /// Shows the dialog and resolves to `true` only if the mock password was
  /// entered correctly - `false` on cancel or on dismissing the barrier.
  static Future<bool> show(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const ExitPasswordDialog(),
    );

    return confirmed ?? false;
  }

  @override
  State<ExitPasswordDialog> createState() => _ExitPasswordDialogState();
}

class _ExitPasswordDialogState extends State<ExitPasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_passwordController.text == ExitPasswordDialog._mockPassword) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _showError = true);
    _passwordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      // A default centered dialog would sit low enough on this fixed 600px
      // display for the on-screen keyboard - which opens immediately, since
      // the field autofocuses - to cover its own Confirm/Cancel buttons.
      // Anchoring near the top keeps the whole dialog clear of that region.
      alignment: const Alignment(0, -0.6),
      title: Text(l10n.text(AppTextKey.settingsExitPasswordTitle)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 320,
            child: OnScreenTextField(
              controller: _passwordController,
              autofocus: true,
              obscureText: true,
              onSubmitted: (_) => _confirm(),
              semanticLabel: l10n.text(AppTextKey.settingsExitPasswordHint),
              hintText: l10n.text(AppTextKey.settingsExitPasswordHint),
            ),
          ),
          if (_showError) ...[
            const SizedBox(height: 8),
            Text(
              l10n.text(AppTextKey.settingsExitPasswordIncorrect),
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.text(AppTextKey.settingsExitPasswordCancelAction)),
        ),
        TextButton(
          onPressed: _confirm,
          child: Text(l10n.text(AppTextKey.settingsExitPasswordConfirmAction)),
        ),
      ],
    );
  }
}
