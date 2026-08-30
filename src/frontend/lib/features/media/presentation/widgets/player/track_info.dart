import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Title, artist and a third context line under the album art.
///
/// The third line used to show album/year, which the backend contract does
/// not provide - it now shows the track's position in the current queue
/// ("TRACK 2 OF 12" / "SINGLE TRACK"), resolved by the caller so this widget
/// stays a plain data-in renderer.
class TrackInfo extends StatelessWidget {
  const TrackInfo({
    required this.title,
    required this.artist,
    required this.contextLine,
    required this.scale,
    super.key,
  });

  final String title;
  final String artist;
  final String contextLine;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppTextStyles.headlineLarge.copyWith(
            color: AppColors.onSurface,
            fontSize: 32 * scale,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          artist.toUpperCase(),
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          contextLine.toUpperCase(),
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
