import 'package:carnine_frontend/features/dashboard/presentation/thermal_warning_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// The overheating warning over whatever page is open (#70). It blocks the
/// page below until the user confirms it, so it cannot go unnoticed.
class ThermalWarningOverlay extends StatelessWidget {
  const ThermalWarningOverlay({required this.controller, super.key});

  final ThermalWarningController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.showsWarning) {
          return const SizedBox.shrink();
        }
        return Stack(
          children: [
            const ModalBarrier(dismissible: false, color: AppColors.scrim),
            Center(
              child: _WarningCard(
                celsius: controller.status.cpuCelsius,
                onConfirm: controller.confirm,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.celsius, required this.onConfirm});

  final double? celsius;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.thermostat,
            color: AppColors.onErrorContainer,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.text(AppTextKey.thermalWarningTitle),
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.onErrorContainer,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.thermalWarningMessage(celsius),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.onErrorContainer,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.onErrorContainer,
              foregroundColor: AppColors.errorContainer,
              minimumSize: const Size(160, 56),
            ),
            child: Text(
              l10n.text(AppTextKey.thermalWarningConfirm),
              style: AppTextStyles.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
