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
    this.wraps = false,
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

  /// A long label (a sound card's full name on the expert page, #207) breaks
  /// into up to three lines with room to the frame, and the button grows
  /// with it; otherwise one line, cut with "…".
  final bool wraps;

  /// The height of a one-line button, and the least of a wrapping one.
  static const double height = 56;

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
      child: ConstrainedBox(
        constraints: wraps
            ? const BoxConstraints(minHeight: height)
            : const BoxConstraints.tightFor(height: height),
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
              child: Padding(
                padding: wraps
                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                    : EdgeInsets.zero,
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
                        maxLines: wraps ? 3 : 1,
                        textAlign: TextAlign.center,
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
      ),
    );
  }
}
