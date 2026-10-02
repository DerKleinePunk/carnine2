import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Full-width action button with an icon and a label: "Titel hinzufügen" on
/// the playlist detail page, "Erstellen"/"Speichern" under a name field.
/// Greyed out and inert while [isEnabled] is `false`.
class MediaWideButton extends StatelessWidget {
  const MediaWideButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isEnabled = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final color = isEnabled ? AppColors.primary : AppColors.outline;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: label,
      child: Material(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          splashColor: AppColors.primary20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isEnabled
                    ? AppColors.primary20
                    : AppColors.outlineVariant20,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
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
