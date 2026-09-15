import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Transient strip for [AudioEventKind.error]/[AudioEventKind.deviceChanged]
/// - same anatomy as [MediaConnectionBanner], but for a passing audio event
/// rather than a persistent connection state: `AudioController` auto-clears
/// it after a few seconds, and a tap dismisses it early. No border, per the
/// design system's "no dividers" rule.
class AudioEventBanner extends StatelessWidget {
  const AudioEventBanner({
    required this.messageKey,
    required this.onDismiss,
    super.key,
  });

  final AppTextKey messageKey;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isError = messageKey == AppTextKey.mediaAudioErrorBanner;

    return Material(
      color: AppColors.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.volume_up,
              color: isError ? AppColors.error : AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.text(messageKey),
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: l10n.text(AppTextKey.mediaDismiss),
              child: InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    l10n.text(AppTextKey.mediaDismiss).toUpperCase(),
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
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
