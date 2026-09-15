import 'package:carnine_frontend/features/media/presentation/audio_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Always-visible system volume row: a mute toggle, a slider and the current
/// percentage - the media page is the only place this is surfaced
/// (`AudioService` is system-wide, but there is no shared app shell across
/// screens yet to host a global control).
class VolumeControl extends StatelessWidget {
  const VolumeControl({required this.controller, super.key});

  static const double _iconButtonSize = 40;

  final AudioController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final percent = controller.volumePercent;
    final isMuted = controller.isMuted;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return Row(
          children: [
            _MuteButton(
              isMuted: isMuted,
              semanticLabel: l10n.text(
                isMuted
                    ? AppTextKey.mediaUnmuteSemantic
                    : AppTextKey.mediaMuteSemantic,
              ),
              onTap: controller.toggleMute,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                slider: true,
                label: l10n.mediaVolumeSemantic(percent),
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 6,
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.surfaceContainerHighest,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary20,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                  ),
                  child: Slider(
                    value: percent.toDouble(),
                    min: 0,
                    max: 100,
                    onChanged: (value) => controller.setVolume(value.round()),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              child: Text(
                '$percent%',
                textAlign: TextAlign.end,
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MuteButton extends StatelessWidget {
  const _MuteButton({
    required this.isMuted,
    required this.semanticLabel,
    required this.onTap,
  });

  final bool isMuted;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          splashColor: AppColors.primary20,
          highlightColor: AppColors.surfaceContainerHighest,
          child: SizedBox(
            width: VolumeControl._iconButtonSize,
            height: VolumeControl._iconButtonSize,
            child: Icon(
              isMuted ? Icons.volume_off : Icons.volume_up,
              color: AppColors.primaryDim,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
