import 'dart:async';

import 'package:carnine_frontend/core/widgets/minute_clock.dart';
import 'package:carnine_frontend/features/controls/data/controls_repository.dart';
import 'package:carnine_frontend/features/controls/presentation/controls_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/cpu_temperature_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
import 'package:carnine_frontend/features/dashboard/presentation/power_supply_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/thermal_warning_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/carnine_top_bar.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/home/music_tile.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/home/navigation_tile.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/home/quick_switches_tile.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/home/vehicle_tile.dart';
import 'package:carnine_frontend/features/maps/presentation/maps_controller.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// The start page (#94): the time and date in large type, and four tiles -
/// navigation, music, quick switches and the vehicle. Navigation and music
/// open their page with a tap; the switches switch; the vehicle only shows.
///
/// Built only while the page is shown: leaving it closes the stream of the
/// switches.
class HomeContent extends StatefulWidget {
  const HomeContent({
    required this.mapsController,
    required this.mediaController,
    required this.powerSupplyController,
    required this.thermalWarningController,
    required this.cpuTemperatureController,
    required this.onOpen,
    this.controlsRepository,
    super.key,
  });

  final MapsController mapsController;
  final MediaController mediaController;
  final PowerSupplyController powerSupplyController;
  final ThermalWarningController thermalWarningController;
  final CpuTemperatureController cpuTemperatureController;

  /// Opens another page, like a tap in the side menu.
  final ValueChanged<DashboardDestination> onOpen;

  /// Where the quick switches come from; without one there is no such tile.
  final ControlsRepository? controlsRepository;

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  static const double _gap = 16;
  static const double _switchesHeight = 176;

  late final ControlsController? _controls = _createControls();

  ControlsController? _createControls() {
    final repository = widget.controlsRepository;
    return repository == null
        ? null
        : ControlsController(repository: repository);
  }

  @override
  void initState() {
    super.initState();
    final controls = _controls;
    if (controls != null) {
      unawaited(controls.start());
    }
  }

  @override
  void dispose() {
    _controls?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          const SizedBox(height: 56, child: _ClockRow()),
          const SizedBox(height: _gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: _leftColumn()),
                const SizedBox(width: _gap),
                Expanded(flex: 3, child: _rightColumn()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leftColumn() {
    final controls = _controls;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: NavigationTile(
            controller: widget.mapsController,
            onTap: () => widget.onOpen(DashboardDestination.maps),
          ),
        ),
        if (controls != null)
          ListenableBuilder(
            listenable: controls,
            builder: (context, _) {
              if (QuickSwitchesTile.switchesOf(controls).isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: _gap),
                child: SizedBox(
                  height: _switchesHeight,
                  child: QuickSwitchesTile(controller: controls),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _rightColumn() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.powerSupplyController,
        widget.thermalWarningController,
        widget.cpuTemperatureController,
      ]),
      builder: (context, _) {
        final power = widget.powerSupplyController.status;
        final thermal = widget.thermalWarningController.status;
        final celsius = widget.cpuTemperatureController.celsius;
        final showVehicle = VehicleTile.hasContent(
          power: power,
          thermal: thermal,
          cpuCelsius: celsius,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: MusicTile(
                controller: widget.mediaController,
                onTap: () => widget.onOpen(DashboardDestination.media),
              ),
            ),
            if (showVehicle) ...[
              const SizedBox(height: _gap),
              Expanded(
                flex: 2,
                child: VehicleTile(
                  power: power,
                  thermal: thermal,
                  cpuCelsius: celsius,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The time large on the left, the date on the right.
class _ClockRow extends StatelessWidget {
  const _ClockRow();

  @override
  Widget build(BuildContext context) {
    return MinuteClock(
      builder: (context, now) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            formatTimeOfDay(context, now),
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.onSurface,
              fontSize: 48,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              MaterialLocalizations.of(context).formatFullDate(now),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
