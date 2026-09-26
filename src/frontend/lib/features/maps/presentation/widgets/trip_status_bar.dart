import 'package:carnine_frontend/features/maps/presentation/format/route_format.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Arrival, remaining time and distance, progress along the route and the
/// cancel button - the bottom bar of the Stitch navigation template.
class TripStatusBar extends StatelessWidget {
  const TripStatusBar({
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.share,
    required this.onCancel,
    this.clock,
    super.key,
  });

  final double remainingMeters;
  final int remainingSeconds;

  /// Part of the route already driven, 0..1.
  final double share;
  final VoidCallback onCancel;

  /// "Now" for the arrival time. The Pi has no RTC, so the page passes the
  /// GPS time of the last fix when it has one.
  final DateTime? clock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = (clock ?? DateTime.now()).toLocal();
    final (arrival, days) = formatArrival(now, remainingSeconds);
    final (distance, distanceUnit) = formatRouteDistance(
      remainingMeters,
      decimalSeparator: l10n.decimalSeparator,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          _TripStat(
            label: l10n.text(
              days == 1
                  ? AppTextKey.mapsArrivalTomorrowLabel
                  : AppTextKey.mapsArrivalLabel,
            ),
            // Two days and more (rare within Germany) as "+2".
            parts: [(arrival, days > 1 ? '+$days' : null)],
          ),
          const SizedBox(width: 20),
          Container(
            width: 1,
            height: 32,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.1),
          ),
          const SizedBox(width: 20),
          _TripStat(
            label: l10n.text(AppTextKey.mapsDurationLabel),
            parts: formatRouteDuration(remainingSeconds),
            valueColor: AppColors.primary,
          ),
          const SizedBox(width: 28),
          Expanded(child: _TripProgressTrack(progress: share.clamp(0.0, 1.0))),
          const SizedBox(width: 28),
          _TripStat(
            label: l10n.text(AppTextKey.mapsDistanceLabel),
            parts: [(distance, distanceUnit)],
            alignEnd: true,
          ),
          const SizedBox(width: 20),
          _CancelButton(onPressed: onCancel),
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.errorContainer,
        foregroundColor: AppColors.onErrorContainer,
        // Touch target per CLAUDE.md, the text keeps the template's size.
        minimumSize: const Size(76, 76),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: AppTextStyles.labelLarge.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      child: Text(l10n.text(AppTextKey.mapsCancelRouteAction)),
    );
  }
}

class _TripStat extends StatelessWidget {
  const _TripStat({
    required this.label,
    required this.parts,
    this.valueColor = AppColors.onSurface,
    this.alignEnd = false,
  });

  final String label;

  /// Value/unit pairs, several for "4 h 49 min"; the unit may be missing.
  final List<(String, String?)> parts;
  final Color valueColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.kineticSubtitle.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            style: AppTextStyles.headlineLarge.copyWith(
              color: valueColor,
              fontSize: 22,
              shadows: valueColor == AppColors.primary
                  ? const [Shadow(color: AppColors.primary40, blurRadius: 8)]
                  : null,
            ),
            children: [
              for (final (index, (value, unit)) in parts.indexed) ...[
                TextSpan(text: index == 0 ? value : ' $value'),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w300,
                      fontSize: 13,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TripProgressTrack extends StatelessWidget {
  const _TripProgressTrack({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 4,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.surfaceContainerHighest),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary40, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment(progress * 2 - 1, 0),
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.white, blurRadius: 8)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
