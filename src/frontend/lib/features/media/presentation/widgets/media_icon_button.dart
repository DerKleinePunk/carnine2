import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';

/// 56dp icon button for the media sub-pages, drawn like [MediaBackButton] so
/// the actions in a page header read as one row (rename and delete on the
/// playlist detail page). Greyed out while [onPressed] is `null`.
class MediaIconButton extends StatelessWidget {
  const MediaIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.color = AppColors.primary,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: semanticLabel,
      child: SizedBox(
        width: 56,
        height: 56,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 26),
          color: isEnabled ? color : AppColors.outline,
          tooltip: semanticLabel,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceContainerHighest,
            side: BorderSide(
              color: isEnabled
                  ? AppColors.primary20
                  : AppColors.outlineVariant20,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
