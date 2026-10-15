import 'dart:async';

import 'package:carnine_frontend/core/widgets/mini_switch.dart';
import 'package:carnine_frontend/core/widgets/offline_retry_view.dart';
import 'package:carnine_frontend/features/settings/data/announcement_settings_store.dart';
import 'package:carnine_frontend/features/settings/presentation/announcement_settings_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// "Ansagen" (#110): switch, loudness and the music's level for the spoken
/// turn instructions, and a button to hear them. Every change goes to the
/// backend at once; a slider sends when it is let go.
class AnnouncementsTab extends StatefulWidget {
  const AnnouncementsTab({required this.store, super.key});

  final AnnouncementSettingsStore store;

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> {
  late final AnnouncementSettingsController _controller =
      AnnouncementSettingsController(store: widget.store);

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) => switch (_controller.status) {
        AnnouncementSettingsStatus.loading => const CenteredMessage(
          messageKey: AppTextKey.mediaLoading,
        ),
        AnnouncementSettingsStatus.offline => OfflineRetryView(
          onRetry: _controller.load,
        ),
        AnnouncementSettingsStatus.ready => _Ready(controller: _controller),
      },
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({required this.controller});

  final AnnouncementSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = controller.isAvailable;
    final errorKey = controller.errorKey;

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SwitchCard(controller: controller),
                const SizedBox(height: 12),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: controller.canTest
                        ? () => unawaited(controller.playTest())
                        : null,
                    icon: Icon(
                      controller.isTesting
                          ? Icons.hourglass_top
                          : Icons.campaign,
                      size: 22,
                    ),
                    label: Text(
                      l10n.text(AppTextKey.settingsAnnouncementsTest),
                    ),
                  ),
                ),
                if (errorKey != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    l10n.text(errorKey),
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SliderCard(
                  title: l10n.text(AppTextKey.settingsAnnouncementsVolume),
                  value: controller.volume,
                  isActive: available,
                  onChanged: controller.dragVolume,
                  onChangeEnd: (percent) =>
                      unawaited(controller.commitVolume(percent)),
                ),
                const SizedBox(height: 12),
                _SliderCard(
                  title: l10n.text(AppTextKey.settingsAnnouncementsMusicUnder),
                  hint: l10n.text(AppTextKey.settingsAnnouncementsMusicHint),
                  value: controller.musicUnder,
                  isActive: available,
                  onChanged: controller.dragMusicUnder,
                  onChangeEnd: (percent) =>
                      unawaited(controller.commitMusicUnder(percent)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The card of the switch: the whole card is the touch target.
class _SwitchCard extends StatelessWidget {
  const _SwitchCard({required this.controller});

  final AnnouncementSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = controller.isAvailable;
    final enabled = controller.isEnabled;
    final title = l10n.text(AppTextKey.settingsAnnouncementsSwitchTitle);
    final subtitle = l10n.text(
      available
          ? AppTextKey.settingsAnnouncementsSwitchSubtitle
          : AppTextKey.settingsAnnouncementsUnavailable,
    );

    return Semantics(
      button: true,
      toggled: available && enabled,
      enabled: available,
      label: title,
      value: subtitle,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: available
              ? () => unawaited(controller.setEnabled(enabled: !enabled))
              : null,
          borderRadius: BorderRadius.circular(8),
          splashColor: AppColors.primary20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: available && enabled
                    ? AppColors.primary
                    : AppColors.outlineVariant20,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.record_voice_over,
                    color: available ? AppColors.primary : AppColors.outline,
                    size: 34,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: available
                                ? AppColors.onSurface
                                : AppColors.onSurfaceVariant,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  MiniSwitch(isOn: enabled, isAvailable: available),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A title with its value in percent and a slider with a large thumb, like
/// the sliders of the Technik page. Greyed out and fixed when not [isActive].
class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.title,
    required this.value,
    required this.isActive,
    required this.onChanged,
    required this.onChangeEnd,
    this.hint,
  });

  final String title;
  final int value;
  final bool isActive;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;

  /// A line of explanation under the slider.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final accent = isActive ? AppColors.primary : AppColors.outline;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppColors.primary20 : AppColors.outlineVariant20,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isActive
                          ? AppColors.onSurface
                          : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$value %',
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: accent,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 14,
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.surfaceContainerHighest,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primary20,
                disabledActiveTrackColor: AppColors.outline,
                disabledInactiveTrackColor: AppColors.surfaceContainerHighest,
                disabledThumbColor: AppColors.outline,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 18,
                  disabledThumbRadius: 18,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 30),
              ),
              child: Slider(
                value: value.clamp(0, 100).toDouble(),
                max: 100,
                divisions: 20,
                semanticFormatterCallback: (v) => '${v.round()} %',
                onChanged: isActive ? (v) => onChanged(v.round()) : null,
                onChangeEnd: isActive ? (v) => onChangeEnd(v.round()) : null,
              ),
            ),
            if (hint case final text?)
              Text(
                text,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
