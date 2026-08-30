import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Strip shown while a rescan is running, or briefly after one just failed
/// for a given folder.
class ScanStatusBar extends StatelessWidget {
  const ScanStatusBar({
    required this.isScanning,
    required this.processed,
    required this.imported,
    required this.failedPath,
    super.key,
  });

  final bool isScanning;
  final int processed;
  final int imported;
  final String? failedPath;

  @override
  Widget build(BuildContext context) {
    if (!isScanning && failedPath == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final message = isScanning
        ? (processed == 0 && imported == 0
            ? l10n.text(AppTextKey.mediaScanRunning)
            : l10n.mediaScanProgressLine(
                processed: processed, imported: imported))
        : l10n.text(AppTextKey.mediaScanFailed);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (isScanning)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            else
              const Icon(Icons.error_outline, color: AppColors.error, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
