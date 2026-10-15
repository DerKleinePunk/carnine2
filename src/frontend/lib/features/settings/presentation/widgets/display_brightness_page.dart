import 'dart:async';

import 'package:carnine_frontend/core/widgets/offline_retry_view.dart';
import 'package:carnine_frontend/features/settings/presentation/display_brightness_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// "Geräte → Display" (#102): the brightness of the backlight, 0 to 100 %.
/// The display follows the thumb while it is dragged. 0 is the darkest level
/// the backend allows, never black.
class DisplayBrightnessPage extends StatefulWidget {
  const DisplayBrightnessPage({required this.controller, super.key});

  final DisplayBrightnessController controller;

  @override
  State<DisplayBrightnessPage> createState() => _DisplayBrightnessPageState();
}

class _DisplayBrightnessPageState extends State<DisplayBrightnessPage> {
  @override
  void initState() {
    super.initState();
    // The state may have changed since the list asked.
    unawaited(widget.controller.load());
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        if (controller.isNotConfigured) {
          return const CenteredMessage(
            messageKey: AppTextKey.settingsDevicesDisplayNotConfigured,
          );
        }
        return switch (controller.status) {
          DisplayBrightnessStatus.loading => const CenteredMessage(
            messageKey: AppTextKey.mediaLoading,
          ),
          DisplayBrightnessStatus.offline => OfflineRetryView(
            onRetry: controller.load,
          ),
          DisplayBrightnessStatus.ready => _Ready(controller: controller),
        };
      },
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({required this.controller});

  final DisplayBrightnessController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final usable = controller.isUsable;
    final accent = usable ? AppColors.primary : AppColors.outline;
    final errorKey = controller.errorKey;

    return SingleChildScrollView(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: usable ? AppColors.primary20 : AppColors.outlineVariant20,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.brightness_6, color: accent, size: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      l10n.text(AppTextKey.settingsDisplayBrightness),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: usable
                            ? AppColors.onSurface
                            : AppColors.onSurfaceVariant,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${controller.percent} %',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: accent,
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 30,
                  ),
                ),
                child: Slider(
                  value: controller.percent.clamp(0, 100).toDouble(),
                  max: 100,
                  divisions: 20,
                  semanticFormatterCallback: (value) => '${value.round()} %',
                  onChanged: usable
                      ? (value) => controller.drag(value.round())
                      : null,
                  onChangeEnd: usable
                      ? (value) => unawaited(controller.commit(value.round()))
                      : null,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _EndLabel(l10n.text(AppTextKey.settingsDisplayDark)),
                  _EndLabel(l10n.text(AppTextKey.settingsDisplayLight)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                l10n.text(
                  usable
                      ? AppTextKey.settingsDisplayBrightnessHint
                      : AppTextKey.settingsDisplayBrightnessUnavailable,
                ),
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              if (errorKey != null) ...[
                const SizedBox(height: 8),
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
      ),
    );
  }
}

class _EndLabel extends StatelessWidget {
  const _EndLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodyLarge.copyWith(
        color: AppColors.onSurfaceVariant,
        fontSize: 12,
      ),
    );
  }
}
