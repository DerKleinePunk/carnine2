import 'package:carnine_frontend/features/dashboard/data/power_supply_source.dart';
import 'package:carnine_frontend/features/dashboard/data/thermal_status_source.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/home/home_tile.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// The vehicle tile of the start page (#94): ignition and input voltage of
/// the car power supply, and the CPU temperature, red when the backend finds
/// the CPU overheated. It only shows. A device without a power supply shows
/// the temperature alone, and without a thermal zone the tile is not there.
class VehicleTile extends StatelessWidget {
  const VehicleTile({
    required this.power,
    required this.thermal,
    required this.cpuCelsius,
    super.key,
  });

  final PowerSupplyStatus power;
  final ThermalStatus thermal;

  /// The live reading; the thermal status only has the one of its last change.
  final double? cpuCelsius;

  /// What the tile can show: `false` means it is left out.
  static bool hasContent({
    required PowerSupplyStatus power,
    required ThermalStatus thermal,
    required double? cpuCelsius,
  }) => power.configured || _temperature(thermal, cpuCelsius) != null;

  static double? _temperature(ThermalStatus thermal, double? cpuCelsius) =>
      cpuCelsius ?? (thermal.overheated ? thermal.cpuCelsius : null);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final temperature = _temperature(thermal, cpuCelsius);

    return HomeTile(
      title: l10n.text(AppTextKey.homeVehicleTitle),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (power.configured) ..._powerRows(l10n),
          if (temperature != null)
            _Row(
              label: l10n.text(AppTextKey.homeVehicleCpu),
              value: '${temperature.round()} °C',
              color: thermal.overheated ? AppColors.error : AppColors.onSurface,
            ),
        ],
      ),
    );
  }

  List<Widget> _powerRows(AppLocalizations l10n) {
    if (!power.connected) {
      return [
        _Row(
          label: l10n.text(AppTextKey.powerSupplyNotResponding),
          icon: Icons.power_off,
          color: AppColors.error,
        ),
      ];
    }
    final color = power.switchingOff ? AppColors.error : AppColors.onSurface;
    final ignition = power.ignition;
    final volts = power.inputVolts;

    return [
      if (ignition != null)
        _Row(
          label: l10n.text(AppTextKey.homeVehicleIgnition),
          value: l10n.text(
            ignition ? AppTextKey.controlsStateOn : AppTextKey.controlsStateOff,
          ),
          color: color,
        ),
      if (volts != null)
        _Row(
          label: l10n.text(AppTextKey.homeVehicleVoltage),
          value:
              '${volts.toStringAsFixed(1).replaceAll('.', l10n.decimalSeparator)} V',
          color: color,
        ),
    ];
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.color, this.value, this.icon});

  final String label;
  final String? value;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (icon case final icon?) ...[
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyLarge.copyWith(
                color: text == null ? color : AppColors.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
          if (text != null) ...[
            const SizedBox(width: 8),
            Text(
              text,
              maxLines: 1,
              style: AppTextStyles.headlineLarge.copyWith(
                color: color,
                fontSize: 22,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
