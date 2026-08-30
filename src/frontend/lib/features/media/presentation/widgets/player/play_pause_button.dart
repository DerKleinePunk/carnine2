import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';

class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({
    required this.isPlaying,
    required this.isEnabled,
    required this.onTap,
    required this.scale,
    super.key,
  });

  static const Duration _animationDuration = Duration(milliseconds: 200);

  final bool isPlaying;
  final bool isEnabled;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = isPlaying
        ? l10n.text(AppTextKey.mediaPauseSemantic)
        : l10n.text(AppTextKey.mediaPlaySemantic);
    final gradientColors = isEnabled
        ? const [AppColors.primary, AppColors.primaryFixed]
        : const [
            AppColors.surfaceContainerHighest,
            AppColors.surfaceContainerHigh
          ];

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: _animationDuration,
            curve: Curves.easeOutCubic,
            width: 80 * scale,
            height: 80 * scale,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              boxShadow: isEnabled
                  ? const [
                      BoxShadow(color: AppColors.primary40, blurRadius: 20)
                    ]
                  : null,
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color:
                  isEnabled ? AppColors.onPrimary : AppColors.onSurfaceVariant,
              size: 36 * scale,
            ),
          ),
        ),
      ),
    );
  }
}
