import 'dart:async';

import 'package:carnine_frontend/features/settings/data/exit_password_store.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/password_field.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

/// Asks for the password before [AppWindow.exitApplication] runs. The backend
/// checks it (`VerifyExitPassword`); without an answer the frontend does not
/// exit (#51).
class ExitPasswordDialog extends StatefulWidget {
  const ExitPasswordDialog({required this.store, super.key});

  /// `null` without a backend: the password cannot be checked then.
  final ExitPasswordStore? store;

  /// Shows the dialog and resolves to `true` only if the backend accepted the
  /// password - `false` on cancel or on dismissing the barrier.
  static Future<bool> show(
    BuildContext context, {
    required ExitPasswordStore? store,
  }) async {
    return await askPassword(context, store: store) != null;
  }

  /// Like [show], but resolves to the password the backend accepted, for a
  /// call that needs it again (the expert page saves with it, #207); `null`
  /// on cancel.
  static Future<String?> askPassword(
    BuildContext context, {
    required ExitPasswordStore? store,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => ExitPasswordDialog(store: store),
    );
  }

  @override
  State<ExitPasswordDialog> createState() => _ExitPasswordDialogState();
}

enum _Problem { wrong, unavailable }

class _ExitPasswordDialogState extends State<ExitPasswordDialog> {
  final Logger _logger = Logger('ExitPasswordDialog');
  final TextEditingController _passwordController = TextEditingController();
  bool _checking = false;
  _Problem? _problem;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_checking) {
      return;
    }
    setState(() {
      _checking = true;
      _problem = null;
    });

    _Problem? problem;
    try {
      final store = widget.store;
      if (store == null) {
        throw const ExitPasswordException(ExitPasswordFailure.unreachable);
      }
      final valid = await store.verify(_passwordController.text);
      if (!mounted) {
        return;
      }
      if (valid) {
        Navigator.of(context).pop(_passwordController.text);
        return;
      }
      problem = _Problem.wrong;
    } on ExitPasswordException catch (error) {
      _logger.info('The password could not be checked: $error');
      problem = _Problem.unavailable;
    }

    if (!mounted) {
      return;
    }
    if (problem == _Problem.wrong) {
      _passwordController.clear();
    }
    setState(() {
      _checking = false;
      _problem = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final problem = _problem;
    final statusKey = _checking
        ? AppTextKey.settingsExitPasswordChecking
        : switch (problem) {
            _Problem.wrong => AppTextKey.settingsExitPasswordIncorrect,
            _Problem.unavailable => AppTextKey.settingsExitPasswordUnavailable,
            null => null,
          };

    return PasswordDialogFrame(
      title: l10n.text(AppTextKey.settingsExitPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 360,
            child: PasswordField(
              controller: _passwordController,
              hintText: l10n.text(AppTextKey.settingsExitPasswordHint),
              onSubmitted: (_) => unawaited(_confirm()),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 360,
            child: PasswordMessage(
              text: statusKey == null ? null : l10n.text(statusKey),
              isError: !_checking,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.text(AppTextKey.settingsExitPasswordCancelAction)),
        ),
        TextButton(
          onPressed: _checking ? null : () => unawaited(_confirm()),
          child: Text(l10n.text(AppTextKey.settingsExitPasswordConfirmAction)),
        ),
      ],
    );
  }
}
