import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// One row in a media list - library results, playlists, playlist entries
/// and add-entry pickers all share this anatomy: a 40dp leading icon tile,
/// two lines of text, and a trailing slot.
///
/// Generalises the player screen's original queue tile (leading art, active
/// state = left cyan border on `surfaceContainerHighest`, ~60dp tall with
/// its existing padding) so every list in the media feature reads as one
/// visual system.
class MediaRowTile extends StatelessWidget {
  const MediaRowTile({
    required this.title,
    required this.subtitle,
    required this.semanticLabel,
    this.leadingIcon = Icons.music_note,
    this.leadingIconColor,
    this.isActive = false,
    this.isEnabled = true,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final String semanticLabel;
  final IconData leadingIcon;
  final Color? leadingIconColor;
  final bool isActive;
  final bool isEnabled;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = !isEnabled
        ? AppColors.onSurfaceVariant
        : (isActive ? AppColors.primary : AppColors.onSurface);
    final iconColor = leadingIconColor ??
        (!isEnabled
            ? AppColors.onSurfaceVariant
            : (isActive ? AppColors.primary : AppColors.onSurfaceVariant));

    return Semantics(
      button: onTap != null,
      enabled: isEnabled,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isActive ? AppColors.surfaceContainerHighest : null,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? const Border(
                  left: BorderSide(color: AppColors.primary, width: 2),
                )
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onTap : null,
            borderRadius: BorderRadius.circular(8),
            splashColor: AppColors.primary20,
            highlightColor: AppColors.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  _Leading(icon: leadingIcon, color: iconColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
