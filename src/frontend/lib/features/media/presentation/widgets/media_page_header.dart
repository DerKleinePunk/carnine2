import 'package:carnine_frontend/features/media/presentation/widgets/media_back_button.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Header shared by every media sub-page: a back button plus a title, in
/// the same typography the original queue header used.
class MediaPageHeader extends StatelessWidget {
  const MediaPageHeader({
    required this.titleKey,
    required this.onBack,
    required this.backSemanticLabelKey,
    super.key,
  });

  final AppTextKey titleKey;
  final VoidCallback onBack;
  final AppTextKey backSemanticLabelKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          MediaBackButton(
              onBack: onBack, semanticLabelKey: backSemanticLabelKey),
          const SizedBox(width: 12),
          Text(
            l10n.text(titleKey).toUpperCase(),
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.onSurface,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
