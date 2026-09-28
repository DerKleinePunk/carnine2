import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Strip shown while the backend cannot start ffprobe/ffmpeg - same anatomy
/// as `UsbImportBanner`. There is no dismiss: the library stays incomplete
/// until ffmpeg is installed, and the rescan clears the strip once it works.
class MediaToolsMissingBanner extends StatelessWidget {
  const MediaToolsMissingBanner({
    required this.onRescan,
    required this.isScanning,
    super.key,
  });

  final VoidCallback onRescan;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: AppColors.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.text(AppTextKey.mediaToolsMissingBanner),
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              enabled: !isScanning,
              label: l10n.text(AppTextKey.mediaRescanSemantic),
              child: InkWell(
                onTap: isScanning ? null : onRescan,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    l10n.text(AppTextKey.mediaRescanAction).toUpperCase(),
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isScanning
                          ? AppColors.onSurfaceVariant
                          : AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
