import 'package:carnine_frontend/features/media/presentation/format/duration_format.dart'
    show formatDuration, formatTrackDuration;
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

class PlayerTimeline extends StatelessWidget {
  const PlayerTimeline({
    required this.position,
    required this.duration,
    super.key,
  });

  final Duration position;

  /// `Duration.zero` when the backend hasn't told us the track's length -
  /// the bar then renders at 0% and the right label shows `--:--`.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.surfaceContainerHighest),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryFixed],
                      ),
                      boxShadow: const [
                        BoxShadow(color: AppColors.primary40, blurRadius: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TimeLabel(text: formatDuration(position)),
            TimeLabel(text: formatTrackDuration(duration)),
          ],
        ),
      ],
    );
  }
}

class TimeLabel extends StatelessWidget {
  const TimeLabel({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelLarge.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
    );
  }
}
