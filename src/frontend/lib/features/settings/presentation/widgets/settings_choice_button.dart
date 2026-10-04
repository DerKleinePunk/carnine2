import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// One choice in a row of exclusive choices - the tabs of "Darstellung &
/// Sprache" and the norm, input and width of the camera. The selected one
/// has a cyan frame; a disabled one is greyed out and does not react.
class SettingsChoiceButton extends StatelessWidget {
  const SettingsChoiceButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.semanticLabel,
    this.icon,
    this.isEnabled = true,
    super.key,
  });

  final String label;

  /// What a screen reader says when it differs from [label], e.g. the
  /// setting's name in front of the value.
  final String? semanticLabel;
  final IconData? icon;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = !isEnabled
        ? AppColors.outline
        : (isSelected ? AppColors.primary : AppColors.onSurfaceVariant);
    final frame = !isEnabled
        ? AppColors.outlineVariant20
        : (isSelected ? AppColors.primary : AppColors.outlineVariant20);

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: isEnabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: SizedBox(
        height: 56,
        child: Material(
          color: isSelected
              ? AppColors.surfaceContainerHighest
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: isEnabled ? onTap : null,
            borderRadius: BorderRadius.circular(8),
            splashColor: AppColors.primary20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: frame),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
