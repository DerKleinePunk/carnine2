import 'dart:async';

import 'package:carnine_frontend/features/maps/presentation/map_follow_zoom_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// "Karte" (#131): how close the map is while it follows the car. One slider
/// with a step for every level from [MapFollowZoomController.minZoom] to
/// [MapFollowZoomController.maxZoom]; the map goes to the level when the thumb
/// is let go, and the backend keeps it.
class FollowZoomTab extends StatelessWidget {
  const FollowZoomTab({required this.controller, super.key});

  final MapFollowZoomController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final shown = controller.shownZoom;
        final errorKey = controller.errorKey;

        return SingleChildScrollView(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.zoom_in,
                        color: AppColors.primary,
                        size: 34,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          l10n.text(AppTextKey.settingsFollowZoomTitle),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: AppColors.onSurface,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$shown',
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: AppColors.primary,
                          fontSize: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.text(AppTextKey.settingsFollowZoomDescription),
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 14,
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.surfaceContainerHighest,
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary20,
                      activeTickMarkColor: AppColors.surface,
                      inactiveTickMarkColor: AppColors.outline,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 18,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 30,
                      ),
                    ),
                    child: Slider(
                      value: shown
                          .clamp(
                            MapFollowZoomController.minZoom,
                            MapFollowZoomController.maxZoom,
                          )
                          .toDouble(),
                      min: MapFollowZoomController.minZoom.toDouble(),
                      max: MapFollowZoomController.maxZoom.toDouble(),
                      divisions:
                          MapFollowZoomController.maxZoom -
                          MapFollowZoomController.minZoom,
                      semanticFormatterCallback: (value) => '${value.round()}',
                      onChanged: (value) => controller.drag(value.round()),
                      onChangeEnd: (value) =>
                          unawaited(controller.commit(value.round())),
                    ),
                  ),
                  // The levels under the slider, with the thumb's width left
                  // at each end so they sit under their stops.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (
                          var level = MapFollowZoomController.minZoom;
                          level <= MapFollowZoomController.maxZoom;
                          level++
                        )
                          Text(
                            '$level',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: level == shown
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.text(AppTextKey.settingsFollowZoomFar),
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        l10n.text(AppTextKey.settingsFollowZoomNear),
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (errorKey != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      l10n.text(errorKey),
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
