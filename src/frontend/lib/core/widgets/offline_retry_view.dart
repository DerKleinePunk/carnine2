import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// A short message in the middle of a page, e.g. "Wird geladen …".
class CenteredMessage extends StatelessWidget {
  const CenteredMessage({required this.messageKey, super.key});

  final AppTextKey messageKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(context).text(messageKey),
        style: AppTextStyles.bodyLarge.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The page could not reach the backend: says so and offers a retry.
class OfflineRetryView extends StatelessWidget {
  const OfflineRetryView({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off,
            color: AppColors.onSurfaceVariant,
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            l10n.text(AppTextKey.mediaOfflineDescription),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 22),
            label: Text(l10n.text(AppTextKey.mediaRetry)),
          ),
        ],
      ),
    );
  }
}
