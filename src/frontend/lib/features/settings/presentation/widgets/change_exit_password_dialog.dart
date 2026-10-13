import 'dart:async';

import 'package:carnine_frontend/features/settings/data/exit_password_store.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/password_field.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

/// Changes the password for "Beenden", one step at a time: the current one,
/// the new one, the new one again. One field per step keeps the dialog small
/// enough to stay clear of the on-screen keyboard (#51).
class ChangeExitPasswordDialog extends StatefulWidget {
  const ChangeExitPasswordDialog({required this.store, super.key});

  /// `null` without a backend: nothing can be changed then.
  final ExitPasswordStore? store;

  static Future<void> show(
    BuildContext context, {
    required ExitPasswordStore? store,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ChangeExitPasswordDialog(store: store),
    );
  }

  @override
  State<ChangeExitPasswordDialog> createState() =>
      _ChangeExitPasswordDialogState();
}

enum _Step { current, next, repeat, done }

class _ChangeExitPasswordDialogState extends State<ChangeExitPasswordDialog> {
  static const double _contentWidth = 360;

  final Logger _logger = Logger('ChangeExitPasswordDialog');
  final TextEditingController _controller = TextEditingController();
  _Step _step = _Step.current;
  bool _busy = false;
  AppTextKey? _problemKey;

  // Kept only while the dialog is open.
  String _current = '';
  String _next = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(_Step step, {AppTextKey? problem}) {
    _controller.clear();
    setState(() {
      _step = step;
      _busy = false;
      _problemKey = problem;
    });
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    switch (_step) {
      case _Step.current:
        await _checkCurrent();
      case _Step.next:
        _takeNext();
      case _Step.repeat:
        await _save();
      case _Step.done:
        Navigator.of(context).pop();
    }
  }

  Future<void> _checkCurrent() async {
    final entered = _controller.text;
    setState(() {
      _busy = true;
      _problemKey = null;
    });
    try {
      final valid = await _storeOrThrow().verify(entered);
      if (!mounted) {
        return;
      }
      if (valid) {
        _current = entered;
        _goTo(_Step.next);
      } else {
        _goTo(_Step.current, problem: AppTextKey.settingsExitPasswordIncorrect);
      }
    } on ExitPasswordException catch (error) {
      _logger.info('The password could not be checked: $error');
      if (mounted) {
        setState(() {
          _busy = false;
          _problemKey = AppTextKey.settingsExitPasswordUnavailable;
        });
      }
    }
  }

  void _takeNext() {
    final entered = _controller.text;
    if (!ExitPasswordRules.isValid(entered)) {
      setState(() => _problemKey = AppTextKey.settingsExitPasswordRules);
      return;
    }
    _next = entered;
    _goTo(_Step.repeat);
  }

  Future<void> _save() async {
    if (_controller.text != _next) {
      _next = '';
      _goTo(_Step.next, problem: AppTextKey.settingsExitPasswordMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _problemKey = null;
    });
    try {
      await _storeOrThrow().change(current: _current, next: _next);
      if (!mounted) {
        return;
      }
      _current = '';
      _next = '';
      _goTo(_Step.done);
    } on ExitPasswordException catch (error) {
      _logger.info('The password was not changed: $error');
      if (!mounted) {
        return;
      }
      switch (error.failure) {
        case ExitPasswordFailure.wrongCurrent:
          _current = '';
          _next = '';
          _goTo(
            _Step.current,
            problem: AppTextKey.settingsExitPasswordIncorrect,
          );
        case ExitPasswordFailure.rejected:
          _next = '';
          _goTo(_Step.next, problem: AppTextKey.settingsExitPasswordRules);
        case ExitPasswordFailure.unreachable:
          setState(() {
            _busy = false;
            _problemKey = AppTextKey.settingsExitPasswordUnavailable;
          });
        case ExitPasswordFailure.failed:
          setState(() {
            _busy = false;
            _problemKey = AppTextKey.settingsExitPasswordSaveFailed;
          });
      }
    }
  }

  ExitPasswordStore _storeOrThrow() {
    final store = widget.store;
    if (store == null) {
      throw const ExitPasswordException(ExitPasswordFailure.unreachable);
    }
    return store;
  }

  AppTextKey get _promptKey => switch (_step) {
    _Step.current => AppTextKey.settingsExitPasswordStepCurrent,
    _Step.next => AppTextKey.settingsExitPasswordStepNew,
    _Step.repeat => AppTextKey.settingsExitPasswordStepRepeat,
    _Step.done => AppTextKey.settingsExitPasswordChanged,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final problemKey = _busy
        ? AppTextKey.settingsExitPasswordChecking
        : _problemKey;
    final isDone = _step == _Step.done;

    return PasswordDialogFrame(
      // The last step has no field: the keyboard goes, the dialog centers.
      keyboardOpen: !isDone,
      title: l10n.text(AppTextKey.settingsDiagnosticsChangePassword),
      content: SizedBox(
        width: _contentWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.text(_promptKey),
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (!isDone) ...[
              const SizedBox(height: 12),
              PasswordField(
                controller: _controller,
                hintText: l10n.text(AppTextKey.settingsExitPasswordHint),
                onSubmitted: (_) => unawaited(_submit()),
              ),
            ],
            if (!isDone) ...[
              const SizedBox(height: 8),
              PasswordMessage(
                text: problemKey == null ? null : l10n.text(problemKey),
                isError: !_busy,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!isDone)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.text(AppTextKey.settingsExitPasswordCancelAction)),
          ),
        TextButton(
          onPressed: _busy ? null : () => unawaited(_submit()),
          child: Text(l10n.text(_actionKey)),
        ),
      ],
    );
  }

  AppTextKey get _actionKey => switch (_step) {
    _Step.current || _Step.next => AppTextKey.settingsExitPasswordNextAction,
    _Step.repeat => AppTextKey.settingsExitPasswordConfirmAction,
    _Step.done => AppTextKey.keyboardDoneAction,
  };
}
