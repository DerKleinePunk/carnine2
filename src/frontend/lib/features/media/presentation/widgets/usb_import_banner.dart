import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Strip shown once a `MUSIK`-labelled USB volume with music is detected -
/// same anatomy as `MediaConnectionBanner`/`AudioEventBanner`, but with two
/// actions instead of one: unlike those, this represents a real decision
/// (`docs/20-media-backend-plan.md` "Verbindlicher Ablauf" requires an
/// explicit "Übernehmen" confirmation before the backend copies anything),
/// so it never auto-dismisses and stays until the user picks one.
class UsbImportBanner extends StatelessWidget {
  const UsbImportBanner({
    required this.sourceLabel,
    required this.matchingFiles,
    required this.onAccept,
    required this.onDismiss,
    super.key,
  });

  final String sourceLabel;
  final int matchingFiles;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: AppColors.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.usb, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.mediaUsbImportBanner(
                  label: sourceLabel,
                  count: matchingFiles,
                ),
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _TextAction(
              label: l10n.text(AppTextKey.mediaDismiss),
              color: AppColors.onSurfaceVariant,
              onTap: onDismiss,
            ),
            const SizedBox(width: 4),
            _TextAction(
              label: l10n.text(AppTextKey.mediaUsbImportAction),
              color: AppColors.primary,
              semanticLabel: l10n.mediaUsbImportSemantic(
                label: sourceLabel,
                count: matchingFiles,
              ),
              onTap: onAccept,
            ),
          ],
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.color,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label.toUpperCase(),
            style: AppTextStyles.labelLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
