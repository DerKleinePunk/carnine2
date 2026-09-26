import 'package:carnine_frontend/features/maps/domain/navigation_failure.dart';
import 'package:carnine_frontend/features/maps/presentation/maps_controller.dart';
import 'package:carnine_frontend/features/maps/presentation/widgets/destination_search.dart';
import 'package:carnine_frontend/features/maps/presentation/widgets/map_icon_button.dart';
import 'package:carnine_frontend/features/maps/presentation/widgets/map_status_pill.dart';
import 'package:carnine_frontend/features/maps/presentation/widgets/trip_status_bar.dart';
import 'package:carnine_frontend/features/maps/presentation/widgets/turn_by_turn_card.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:local_map/local_map.dart';

/// Maps/navigation tab: the offline map (`local_map`) with the overlays of
/// the Stitch template (`docs/stitch_car_pc/carnine_navigation_1024x600`).
///
/// Tiles are read directly from the MBTiles file (ADR-021 exception);
/// search, routes and positions come from the backend's NavigationService
/// through [MapsController].
class MapsContent extends StatelessWidget {
  const MapsContent({required this.controller, super.key});

  final MapsController controller;

  static final MapConfig _mapConfig = MapConfig(
    minZoom: 8,
    maxZoom: 17,
    initialZoom: 13,
    vectorStyleAssets: const ['assets/maps/style_carnine_dark.json'],
    initialVectorStyleIndex: 0,
  );

  static const _layerStyle = MapLayerStyle(
    // The background layer of style_carnine_dark.json; without it the map
    // flashes light grey until the first tiles are drawn. Lighter than the
    // app's surface: the 7-inch panel swallows anything darker.
    backgroundColor: AppColors.surfaceContainer,
    routeColor: AppColors.primary,
    routeWidth: 6,
    positionColor: AppColors.primary,
    onPositionColor: AppColors.surface,
    startColor: AppColors.onSurfaceVariant,
    destinationColor: AppColors.secondary,
    highlightColor: AppColors.secondary,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: AppColors.surface,
          child: MapView(
            mbtilesPath: MapsController.tilesPath(),
            config: _mapConfig,
            controller: controller.map,
            layerStyle: _layerStyle,
            errorBuilder: (context, error) => _MapErrorView(error: error),
          ),
        ),
        ListenableBuilder(
          listenable: Listenable.merge([controller, controller.map]),
          builder: (context, _) => _Overlays(controller: controller),
        ),
      ],
    );
  }
}

class _Overlays extends StatelessWidget {
  const _Overlays({required this.controller});

  final MapsController controller;

  LocalMapController get _map => controller.map;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = _map.progress;
    final next = progress?.nextManeuver;
    final toNext = progress?.distanceToNextManeuverMeters;
    final status = _statusText(l10n);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (status != null)
          Positioned(
            top: 92,
            left: 0,
            right: 0,
            child: Center(
              child: MapStatusPill(
                text: status.$1,
                isError: status.$2,
                icon: status.$2 ? Icons.warning_amber_rounded : Icons.sync,
              ),
            ),
          ),
        if (next != null && toNext != null)
          Positioned(
            top: 16,
            left: 24,
            child: TurnByTurnCard(maneuver: next, meters: toNext),
          ),
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(child: _search(l10n)),
        ),
        Positioned(
          right: 12,
          top: 0,
          bottom: 0,
          child: Center(child: _buttons(l10n)),
        ),
        if (_map.route != null)
          Positioned(left: 24, right: 100, bottom: 20, child: _tripBar())
        else if (_map.locationName case final name?)
          Positioned(
            left: 24,
            bottom: 20,
            child: MapStatusPill(text: name.label, icon: Icons.near_me),
          ),
      ],
    );
  }

  Widget _search(AppLocalizations l10n) {
    final failure = controller.searchFailure;
    String? message;
    if (failure != null) {
      message = l10n.text(AppTextKey.mapsRoutingOffline);
    } else if (controller.noResults) {
      message = l10n.text(AppTextKey.mapsSearchNoResults);
    }
    return DestinationSearch(
      results: controller.results,
      searching: controller.searching,
      message: message,
      near: _map.position?.position,
      onChanged: controller.search,
      onSelected: controller.selectDestination,
    );
  }

  Widget _buttons(AppLocalizations l10n) {
    final navigating = controller.navigationMode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MapIconButton(
          icon: Icons.add,
          semanticLabel: l10n.text(AppTextKey.mapsZoomInSemantic),
          color: AppColors.primary,
          onTap: _map.zoomIn,
        ),
        MapIconButton(
          icon: Icons.remove,
          semanticLabel: l10n.text(AppTextKey.mapsZoomOutSemantic),
          color: AppColors.primary,
          onTap: _map.zoomOut,
        ),
        const SizedBox(height: 16),
        MapIconButton(
          icon: navigating ? Icons.navigation : Icons.explore,
          semanticLabel: l10n.text(
            navigating
                ? AppTextKey.mapsNorthUpSemantic
                : AppTextKey.mapsNavigationModeSemantic,
          ),
          color: AppColors.secondary,
          active: navigating,
          onTap: controller.toggleNavigationMode,
        ),
      ],
    );
  }

  Widget _tripBar() {
    final route = _map.route;
    final progress = _map.progress;
    final remaining = progress?.remainingMeters ?? route?.distanceMeters ?? 0;
    final traveled = progress?.traveledMeters ?? 0;
    final total = traveled + remaining;
    return TripStatusBar(
      remainingMeters: remaining,
      remainingSeconds:
          progress?.remainingSeconds ?? route?.durationSeconds ?? 0,
      share: total <= 0 ? 0 : traveled / total,
      clock: _map.position?.timestampUtc,
      onCancel: controller.cancelRoute,
    );
  }

  /// Text and whether it is an error; `null` when there is nothing to say.
  (String, bool)? _statusText(AppLocalizations l10n) {
    if (!controller.backendReachable) {
      return (l10n.text(AppTextKey.mapsRoutingOffline), true);
    }
    if (_map.isRouting) {
      return (l10n.text(AppTextKey.mapsRouteCalculating), false);
    }
    final failure = controller.routeFailure;
    if (failure == null) return null;
    final key = switch (failure) {
      NavigationFailureKind.notFound => AppTextKey.mapsNoRouteFound,
      NavigationFailureKind.noPosition => AppTextKey.mapsNoPosition,
      NavigationFailureKind.offline => AppTextKey.mapsRoutingOffline,
      NavigationFailureKind.unknown => AppTextKey.mapsRouteError,
    };
    return (l10n.text(key), true);
  }
}

/// Replaces the map when it cannot be drawn: no MBTiles file installed, or a
/// file or style the map cannot read. The details go to the log.
class _MapErrorView extends StatelessWidget {
  const _MapErrorView({required this.error});

  final MapError error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final missing =
        error.category == MapErrorCategory.noMapData ||
        error.category == MapErrorCategory.mbtilesMissing;
    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              missing ? Icons.map_outlined : Icons.error_outline,
              size: 64,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.text(
                missing
                    ? AppTextKey.mapsNoMapData
                    : AppTextKey.mapsMapUnavailable,
              ),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
