import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';

/// Back button for the media sub-pages (library/collections, playlist
/// detail, create, add-entries).
class MediaBackButton extends StatelessWidget {
  const MediaBackButton({
    required this.onBack,
    required this.semanticLabelKey,
    super.key,
  });

  final VoidCallback onBack;
  final AppTextKey semanticLabelKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = l10n.text(semanticLabelKey);

    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: 56,
        height: 56,
        child: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 26),
          color: AppColors.primary,
          tooltip: label,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceContainerHighest,
            side: const BorderSide(color: AppColors.primary20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
