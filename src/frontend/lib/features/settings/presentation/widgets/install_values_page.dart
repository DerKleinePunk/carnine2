import 'dart:async';

import 'package:carnine_frontend/core/widgets/mini_switch.dart';
import 'package:carnine_frontend/core/widgets/offline_retry_view.dart';
import 'package:carnine_frontend/features/settings/data/install_values_store.dart';
import 'package:carnine_frontend/features/settings/presentation/install_values_controller.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/install_value_dialogs.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/settings_choice_button.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// "System → Experten" (#207): the installation values the backend lists,
/// grouped under its headings, each with its help, where it comes from and
/// whether it waits for a restart. Changes collect until "Speichern".
///
/// The page knows no key: every field is built from the value's kind. Label,
/// help and headings are the backend's (German for now).
class InstallValuesPage extends StatefulWidget {
  const InstallValuesPage({
    required this.controller,
    required this.askPassword,
    super.key,
  });

  final InstallValuesController controller;

  /// Asks for the exit password again when the backend refused the one given
  /// on opening (changed in the meantime); `null` on cancel.
  final Future<String?> Function() askPassword;

  /// Up to this many choices stand as buttons in the row; more open a list.
  static const int maxInlineChoices = 4;

  @override
  State<InstallValuesPage> createState() => _InstallValuesPageState();
}

class _InstallValuesPageState extends State<InstallValuesPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.load());
  }

  Future<void> _save() async {
    final controller = widget.controller;
    var outcome = await controller.save();
    while (outcome == InstallSaveOutcome.wrongPassword && mounted) {
      final password = await widget.askPassword();
      if (password == null) {
        return;
      }
      controller.updatePassword(password);
      outcome = await controller.save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => switch (controller.status) {
        InstallValuesStatus.loading => const CenteredMessage(
          messageKey: AppTextKey.mediaLoading,
        ),
        InstallValuesStatus.offline => OfflineRetryView(
          onRetry: controller.load,
        ),
        InstallValuesStatus.ready => Column(
          children: [
            Expanded(child: _ValueList(controller: controller)),
            _SaveBar(controller: controller, onSave: _save),
          ],
        ),
      },
    );
  }
}

class _ValueList extends StatelessWidget {
  const _ValueList({required this.controller});

  final InstallValuesController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final values = controller.values;
    if (values.settings.isEmpty) {
      return const CenteredMessage(messageKey: AppTextKey.settingsExpertsEmpty);
    }

    return ListView(
      children: [
        if (values.uiDropInError.isNotEmpty)
          _Notice(
            title: l10n.text(AppTextKey.settingsExpertsDropInError),
            detail: values.uiDropInError,
            isError: true,
          ),
        if (values.restartRequired)
          _Notice(title: l10n.text(AppTextKey.settingsExpertsRestartHint)),
        for (final (group, items) in controller.groups) ...[
          _GroupHeading(text: group),
          for (final value in items)
            _ValueRow(
              key: ValueKey<String>('install-${value.key}'),
              value: value,
              controller: controller,
            ),
        ],
      ],
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 0, 8),
      child: Text(
        text,
        style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A notice over the list: the page's file was left out (red), or values
/// wait for a restart.
class _Notice extends StatelessWidget {
  const _Notice({required this.title, this.detail, this.isError = false});

  final String title;
  final String? detail;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final text = detail;
    final foreground = isError
        ? AppColors.onErrorContainer
        : AppColors.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.errorContainer
            : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.restart_alt,
            color: isError ? AppColors.onErrorContainer : AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (text != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: foreground,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The choices a row offers: for a sound card the system's default first,
/// and a saved value the device lacks now stays visible.
List<InstallValueChoice> choicesOf(
  AppLocalizations l10n,
  InstallValue value,
  String shown,
) {
  final choices = [
    if (value.kind == InstallValueKind.soundCard)
      InstallValueChoice(
        value: '',
        label: l10n.text(AppTextKey.settingsExpertsSystemDefault),
      ),
    ...value.choices,
  ];
  if (shown.isNotEmpty && choices.every((choice) => choice.value != shown)) {
    choices.add(
      InstallValueChoice(value: shown, label: l10n.expertsMissingChoice(shown)),
    );
  }
  return choices;
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.value, required this.controller, super.key});

  final InstallValue value;
  final InstallValuesController controller;

  bool get _isChoice =>
      value.kind == InstallValueKind.choice ||
      value.kind == InstallValueKind.soundCard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shown = controller.shownValue(value);
    final choices = _isChoice
        ? choicesOf(l10n, value, shown)
        : const <InstallValueChoice>[];
    final inline =
        _isChoice && choices.length <= InstallValuesPage.maxInlineChoices;
    final changed = controller.isChanged(value.key);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: changed ? AppColors.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: inline ? null : () => unawaited(_edit(context, shown)),
          borderRadius: BorderRadius.circular(8),
          splashColor: AppColors.primary20,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _RowText(value: value)),
                    if (!inline) ...[
                      const SizedBox(width: 12),
                      _Trailing(value: value, shown: shown, choices: choices),
                    ],
                  ],
                ),
                if (inline) ...[
                  const SizedBox(height: 10),
                  _InlineChoices(
                    value: value,
                    choices: choices,
                    selected: shown,
                    onSelect: (choice) => _choose(choice),
                  ),
                ],
                const SizedBox(height: 6),
                _RowMeta(value: value, controller: controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A sound card's "system default" is the reset; any other choice a value.
  void _choose(String choice) {
    if (value.kind == InstallValueKind.soundCard && choice.isEmpty) {
      controller.reset(value);
    } else {
      controller.change(value, choice);
    }
  }

  Future<void> _edit(BuildContext context, String shown) async {
    final l10n = AppLocalizations.of(context);
    switch (value.kind) {
      case InstallValueKind.boolean:
        controller.change(value, shown == 'true' ? 'false' : 'true');
      case InstallValueKind.integer || InstallValueKind.text:
        final text = await showInstallValueDialog(
          context,
          value: value,
          current: shown,
        );
        if (text != null) {
          controller.change(value, text);
        }
      case InstallValueKind.choice || InstallValueKind.soundCard:
        final choice = await showInstallChoiceDialog(
          context,
          title: value.label,
          choices: choicesOf(l10n, value, shown),
          selected: shown,
        );
        if (choice != null) {
          _choose(choice);
        }
      case InstallValueKind.unknown:
        break;
    }
  }
}

class _RowText extends StatelessWidget {
  const _RowText({required this.value});

  final InstallValue value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value.label,
          style: AppTextStyles.headlineLarge.copyWith(
            color: AppColors.onSurface,
            fontSize: 16,
          ),
        ),
        if (value.help.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            value.help,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

/// The value on the right of a row that is changed by a tap: a switch, or
/// the text with an arrow to its dialog.
class _Trailing extends StatelessWidget {
  const _Trailing({
    required this.value,
    required this.shown,
    required this.choices,
  });

  final InstallValue value;
  final String shown;
  final List<InstallValueChoice> choices;

  @override
  Widget build(BuildContext context) {
    if (value.kind == InstallValueKind.boolean) {
      return MiniSwitch(isOn: shown == 'true', isAvailable: true);
    }
    final l10n = AppLocalizations.of(context);
    final text = switch (value.kind) {
      _ when shown.isEmpty && value.kind != InstallValueKind.soundCard =>
        l10n.text(AppTextKey.settingsExpertsNotSet),
      InstallValueKind.integer =>
        value.unit.isEmpty ? shown : '$shown ${value.unit}',
      InstallValueKind.choice || InstallValueKind.soundCard =>
        choices.firstWhere((choice) => choice.value == shown).label,
      _ => shown,
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.primary,
                fontSize: 16,
              ),
            ),
          ),
          if (value.kind != InstallValueKind.unknown) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right,
              color: AppColors.onSurfaceVariant,
              size: 24,
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineChoices extends StatelessWidget {
  const _InlineChoices({
    required this.value,
    required this.choices,
    required this.selected,
    required this.onSelect,
  });

  final InstallValue value;
  final List<InstallValueChoice> choices;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // As high as the tallest: a long sound card name wraps.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, choice) in choices.indexed) ...[
            if (index > 0) const SizedBox(width: 10),
            Expanded(
              child: SettingsChoiceButton(
                label: choice.label,
                semanticLabel: '${value.label}: ${choice.label}',
                isSelected: choice.value == selected,
                wraps: true,
                onTap: () => onSelect(choice.value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Where the value comes from, whether it is changed or waits for a restart,
/// and "Zurücksetzen" where the value may be unset.
class _RowMeta extends StatelessWidget {
  const _RowMeta({required this.value, required this.controller});

  final InstallValue value;
  final InstallValuesController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final key = value.key;
    final resetting = controller.isResetPending(key);
    final parts = [
      if (resetting)
        l10n.text(AppTextKey.settingsExpertsResetPending)
      else if (controller.isChanged(key))
        l10n.text(AppTextKey.settingsExpertsChanged)
      else if (value.isDefault)
        l10n.text(AppTextKey.settingsExpertsDefault)
      else
        value.origin.split('/').last,
      if (value.restartPending)
        l10n.text(AppTextKey.settingsExpertsRestartPending),
    ];
    final canReset =
        value.optional &&
        !resetting &&
        (!value.isDefault || controller.isChanged(key));

    return Row(
      children: [
        Expanded(
          child: Text(
            parts.join(' · '),
            style: AppTextStyles.bodyLarge.copyWith(
              color: value.restartPending
                  ? AppColors.primary
                  : AppColors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ),
        if (canReset)
          TextButton(
            onPressed: () => controller.reset(value),
            child: Text(l10n.text(AppTextKey.settingsExpertsReset)),
          ),
      ],
    );
  }
}

/// The bar under the list while there are changes, or a save just ended:
/// how many, "Verwerfen" and "Speichern"; after a save how it went.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.controller, required this.onSave});

  final InstallValuesController controller;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final outcome = controller.outcome;
    if (!controller.hasChanges && !controller.isSaving && outcome == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final isError = outcome != null && outcome != InstallSaveOutcome.saved;
    final busy = controller.isSaving;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.errorContainer
            : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _message(l10n),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyLarge.copyWith(
                color: isError
                    ? AppColors.onErrorContainer
                    : AppColors.onSurface,
                fontSize: 14,
              ),
            ),
          ),
          if (controller.hasChanges) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: busy ? null : controller.discard,
              child: Text(l10n.text(AppTextKey.settingsExpertsDiscard)),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: busy ? null : () => unawaited(onSave()),
              icon: const Icon(Icons.save, size: 20),
              label: Text(l10n.text(AppTextKey.settingsExpertsSave)),
            ),
          ],
        ],
      ),
    );
  }

  String _message(AppLocalizations l10n) {
    if (controller.isSaving) {
      return l10n.text(AppTextKey.settingsExpertsSaving);
    }
    return switch (controller.outcome) {
      InstallSaveOutcome.saved => l10n.text(AppTextKey.settingsExpertsSaved),
      InstallSaveOutcome.rejected =>
        '${l10n.text(AppTextKey.settingsExpertsRejected)} '
            '${controller.rejection}',
      InstallSaveOutcome.unreachable => l10n.text(
        AppTextKey.settingsExpertsUnreachable,
      ),
      InstallSaveOutcome.failed || InstallSaveOutcome.wrongPassword =>
        l10n.text(AppTextKey.settingsExpertsFailed),
      null => l10n.expertsChanges(controller.changeCount),
    };
  }
}
