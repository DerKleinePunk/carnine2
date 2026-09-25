import 'package:carnine_frontend/features/maps/presentation/widgets/maneuver_icon.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:local_map/local_map.dart';

/// Next maneuver with distance, from the library's [RouteProgress].
class TurnByTurnCard extends StatelessWidget {
  const TurnByTurnCard({
    required this.maneuver,
    required this.meters,
    super.key,
  });

  final RoutingManeuver maneuver;
  final double meters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (value, unit) = formatDistance(meters);
    // Street name if the router has one, else the whole instruction.
    final names = maneuver.streetNames;
    final target = names.isNotEmpty ? names.first : maneuver.instruction;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: _decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                maneuverIcon(maneuver.type),
                color: AppColors.primary,
                size: 36,
                shadows: const [
                  Shadow(color: AppColors.primary40, blurRadius: 8),
                ],
              ),
              const Spacer(),
              _Distance(value: value, unit: unit),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.text(AppTextKey.mapsNextTurnLabel).toUpperCase(),
            style: AppTextStyles.kineticSubtitle.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            target,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.onSurface,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  static const _decoration = BoxDecoration(
    color: AppColors.surfaceContainerHigh,
    borderRadius: BorderRadius.all(Radius.circular(8)),
    border: Border(left: BorderSide(color: AppColors.primary, width: 4)),
    boxShadow: [
      BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 10)),
    ],
  );
}

class _Distance extends StatelessWidget {
  const _Distance({required this.value, required this.unit});

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTextStyles.headlineLarge.copyWith(
          color: AppColors.onSurface,
          fontSize: 22,
        ),
        children: [
          TextSpan(text: '$value '),
          TextSpan(
            text: unit,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}
