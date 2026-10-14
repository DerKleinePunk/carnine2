import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// What the turn card says when the car has left the route (#103).
enum RerouteNotice {
  /// The route is being calculated again.
  recalculating,

  /// The car is off the route and the new calculation did not work (routing
  /// not reachable); the old route stays on the map.
  unavailable,
}

/// The notice for the state of [LocalMapController]: `null` while the car is
/// on its route, or when it left it and a calculation is still to start.
///
/// - being recalculated: [RerouteNotice.recalculating]
/// - off the route and the last calculation failed:
///   [RerouteNotice.unavailable]
RerouteNotice? rerouteNoticeFor({
  required bool isRerouting,
  required bool offRoute,
  required String? rerouteError,
}) {
  if (isRerouting) {
    return RerouteNotice.recalculating;
  }
  if (offRoute && rerouteError != null) {
    return RerouteNotice.unavailable;
  }
  return null;
}

/// The turn card of the map while the route is recalculated: the same card,
/// with the notice instead of the next turn - the turn on the old route would
/// be wrong, the car is no longer on it.
class RerouteNoticeCard extends StatelessWidget {
  const RerouteNoticeCard({required this.notice, super.key});

  final RerouteNotice notice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isError = notice == RerouteNotice.unavailable;
    final color = isError ? AppColors.error : AppColors.primary;
    final text = l10n.text(
      isError ? AppTextKey.mapsOffRouteUnavailable : AppTextKey.mapsRerouting,
    );

    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.warning_amber_rounded : Icons.sync,
              color: color,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.onSurface,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
