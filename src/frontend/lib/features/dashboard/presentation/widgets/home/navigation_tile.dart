import 'package:carnine_frontend/features/dashboard/presentation/widgets/home/home_tile.dart';
import 'package:carnine_frontend/features/maps/presentation/format/route_format.dart';
import 'package:carnine_frontend/features/maps/presentation/maps_controller.dart';
import 'package:carnine_frontend/features/maps/presentation/widgets/maneuver_icon.dart';
import 'package:carnine_frontend/features/maps/presentation/widgets/reroute_notice_card.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

/// The navigation tile of the start page (#94): with a route the next turn,
/// the way to it, the way left and the arrival; without one the invitation to
/// enter a destination. A tap opens the map. The data is the one the map
/// page shows.
class NavigationTile extends StatelessWidget {
  const NavigationTile({
    required this.controller,
    required this.onTap,
    super.key,
  });

  final MapsController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.map]),
      builder: (context, _) {
        final map = controller.map;
        final route = map.route;
        if (route == null) {
          return NavigationTileView(
            gps: controller.gps,
            isRouting: map.isRouting,
            onTap: onTap,
          );
        }
        final progress = map.progress;
        final next = progress?.nextManeuver;
        final toNext = progress?.distanceToNextManeuverMeters;

        return NavigationTileView(
          gps: controller.gps,
          onTap: onTap,
          trip: NavigationTrip(
            // Off the route the next turn is the old route's (#103).
            notice: rerouteNoticeFor(
              isRerouting: map.isRerouting,
              offRoute: map.offRoute,
              rerouteError: map.rerouteError,
            ),
            maneuverType: next?.type,
            metersToNext: next == null ? null : toNext,
            target: next == null
                ? null
                : (next.streetNames.isNotEmpty
                      ? next.streetNames.first
                      : next.instruction),
            remainingMeters: progress?.remainingMeters ?? route.distanceMeters,
            remainingSeconds:
                progress?.remainingSeconds ?? route.durationSeconds,
            // The Pi has no RTC: the GPS time of the last fix, when it has
            // one.
            now: (map.position?.timestampUtc ?? clock.now()).toLocal(),
          ),
        );
      },
    );
  }
}

/// What the tile shows of a route being driven.
class NavigationTrip {
  const NavigationTrip({
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.now,
    this.notice,
    this.maneuverType,
    this.metersToNext,
    this.target,
  });

  /// Instead of the turn, while the route is calculated again.
  final RerouteNotice? notice;

  /// Valhalla's type of the next turn, its distance and the street or
  /// instruction; `null` before the first progress.
  final int? maneuverType;
  final double? metersToNext;
  final String? target;

  final double remainingMeters;
  final int remainingSeconds;

  /// The time of day the arrival is counted from.
  final DateTime now;
}

/// The tile for a given state, without the controllers.
class NavigationTileView extends StatelessWidget {
  const NavigationTileView({
    required this.gps,
    required this.onTap,
    this.trip,
    this.isRouting = false,
    super.key,
  });

  final GpsState gps;
  final VoidCallback onTap;

  /// `null` without a route.
  final NavigationTrip? trip;

  /// A route is being calculated, without one on the map yet.
  final bool isRouting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trip = this.trip;

    return HomeTile(
      title: l10n.text(AppTextKey.homeNavigationTitle),
      trailing: _GpsIndicator(state: gps),
      onTap: onTap,
      child: trip == null ? _NoRoute(isRouting: isRouting) : _Route(trip: trip),
    );
  }
}

class _NoRoute extends StatelessWidget {
  const _NoRoute({required this.isRouting});

  final bool isRouting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = l10n.text(
      isRouting
          ? AppTextKey.mapsRouteCalculating
          : AppTextKey.mapsSearchPlaceholder,
    );

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRouting ? Icons.sync : Icons.search,
            color: AppColors.primary,
            size: 44,
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.onSurface,
                fontSize: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Route extends StatelessWidget {
  const _Route({required this.trip});

  final NavigationTrip trip;

  @override
  Widget build(BuildContext context) {
    final notice = trip.notice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: notice != null
              ? _NoticeLine(notice: notice)
              : _NextTurn(
                  maneuverType: trip.maneuverType,
                  meters: trip.metersToNext,
                  target: trip.target,
                ),
        ),
        const SizedBox(height: 8),
        _Stats(
          remainingMeters: trip.remainingMeters,
          remainingSeconds: trip.remainingSeconds,
          now: trip.now,
        ),
      ],
    );
  }
}

class _NextTurn extends StatelessWidget {
  const _NextTurn({
    required this.maneuverType,
    required this.meters,
    required this.target,
  });

  final int? maneuverType;
  final double? meters;
  final String? target;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final distance = meters;
    final name = target;

    return Row(
      children: [
        Icon(
          maneuverIcon(maneuverType),
          color: AppColors.primary,
          size: 72,
          shadows: const [Shadow(color: AppColors.primary40, blurRadius: 12)],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (distance != null)
                _Value(
                  parts: [
                    formatRouteDistance(
                      distance,
                      decimalSeparator: l10n.decimalSeparator,
                    ),
                  ],
                  size: 40,
                ),
              if (name != null)
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: AppColors.onSurface,
                    fontSize: 20,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// While the route is calculated again: the notice of the map in place of
/// the turn.
class _NoticeLine extends StatelessWidget {
  const _NoticeLine({required this.notice});

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
      child: Row(
        children: [
          Icon(
            isError ? Icons.warning_amber_rounded : Icons.sync,
            color: color,
            size: 56,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.onSurface,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.now,
  });

  final double remainingMeters;
  final int remainingSeconds;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (arrival, days) = formatArrival(now, remainingSeconds);
    final distance = formatRouteDistance(
      remainingMeters,
      decimalSeparator: l10n.decimalSeparator,
    );

    return Row(
      children: [
        Expanded(
          child: _Stat(
            label: l10n.text(
              days == 1
                  ? AppTextKey.mapsArrivalTomorrowLabel
                  : AppTextKey.mapsArrivalLabel,
            ),
            // Two days and more (rare within Germany) as "+2".
            parts: [(arrival, days > 1 ? '+$days' : '')],
          ),
        ),
        Expanded(
          child: _Stat(
            label: l10n.text(AppTextKey.mapsDistanceLabel),
            parts: [distance],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.parts});

  final String label;
  final List<(String, String)> parts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.kineticSubtitle.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        _Value(parts: parts, size: 24),
      ],
    );
  }
}

/// A number and its unit, the unit smaller and paler.
class _Value extends StatelessWidget {
  const _Value({required this.parts, required this.size});

  final List<(String, String)> parts;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: RichText(
        maxLines: 1,
        text: TextSpan(
          style: AppTextStyles.headlineLarge.copyWith(
            color: AppColors.onSurface,
            fontSize: size,
          ),
          children: [
            for (final (value, unit) in parts) ...[
              TextSpan(text: value),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w300,
                    fontSize: size * 0.55,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A dot and a word for the GPS: the primary color with a fix, red without.
/// Nothing while the device has no position source.
class _GpsIndicator extends StatelessWidget {
  const _GpsIndicator({required this.state});

  final GpsState state;

  @override
  Widget build(BuildContext context) {
    if (state == GpsState.none) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final hasFix = state == GpsState.fix;
    final color = hasFix ? AppColors.primary : AppColors.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: hasFix
                ? const [BoxShadow(color: AppColors.primary40, blurRadius: 6)]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          l10n.text(hasFix ? AppTextKey.homeGpsFix : AppTextKey.mapsNoPosition),
          style: AppTextStyles.labelLarge.copyWith(color: color, fontSize: 12),
        ),
      ],
    );
  }
}
