import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// A slider of the Technik page, as wide as the page: the name on the left,
/// a draggable slider with a large thumb in the middle, the value on the
/// right. Greyed out and fixed without its module.
class ControlSliderCard extends StatelessWidget {
  const ControlSliderCard({
    required this.name,
    required this.level,
    required this.min,
    required this.max,
    required this.isAvailable,
    required this.onChanged,
    required this.onChangeEnd,
    super.key,
  });

  /// What the user called it - shown as it is, not translated.
  final String name;
  final int level;
  final int min;
  final int max;
  final bool isAvailable;

  /// While the thumb is dragged.
  final ValueChanged<int> onChanged;

  /// When the thumb is let go.
  final ValueChanged<int> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = isAvailable ? AppColors.primary : AppColors.outline;
    final shown = level.clamp(min, max);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAvailable ? AppColors.primary20 : AppColors.outlineVariant20,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.tune, color: accent, size: 34),
            const SizedBox(width: 14),
            SizedBox(
              width: 200,
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.headlineLarge.copyWith(
                  color: isAvailable
                      ? AppColors.onSurface
                      : AppColors.onSurfaceVariant,
                  fontSize: 18,
                ),
              ),
            ),
            Expanded(
              child: SliderTheme(
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
                  value: shown.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  semanticFormatterCallback: (value) => '${value.round()} %',
                  onChanged: isAvailable
                      ? (value) => onChanged(value.round())
                      : null,
                  onChangeEnd: isAvailable
                      ? (value) => onChangeEnd(value.round())
                      : null,
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                isAvailable
                    ? '$shown %'
                    : l10n.text(AppTextKey.controlsUnavailable).toUpperCase(),
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: isAvailable
                    ? AppTextStyles.headlineLarge.copyWith(
                        color: accent,
                        fontSize: 24,
                      )
                    : AppTextStyles.labelLarge.copyWith(
                        color: AppColors.outline,
                        fontWeight: FontWeight.w700,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
