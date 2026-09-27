import 'dart:async';

import 'package:carnine_frontend/features/dashboard/data/power_supply_source.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

/// Compact top bar with system indicators and the time of day.
class CarnineTopBar extends StatelessWidget {
  const CarnineTopBar({this.powerSupply = PowerSupplyStatus.none, super.key});

  /// Shown only on a device with a car power supply.
  final PowerSupplyStatus powerSupply;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const _StatusIcon(icon: Icons.signal_cellular_4_bar),
            const _StatusIcon(icon: Icons.battery_full),
            const _StatusIcon(icon: Icons.light_mode),
            if (powerSupply.configured)
              PowerSupplyIndicator(status: powerSupply),
            const _Divider(),
            const TopBarClock(),
          ],
        ),
      ),
    );
  }
}

/// Time of day in the active locale's format, redrawn on each minute change.
class TopBarClock extends StatefulWidget {
  const TopBarClock({super.key});

  @override
  State<TopBarClock> createState() => _TopBarClockState();
}

class _TopBarClockState extends State<TopBarClock> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = clock.now();
    _scheduleNextTick();
  }

  // One-shot timers aimed at the next minute boundary, so the display neither
  // drifts nor wakes the UI more than once a minute.
  void _scheduleNextTick() {
    final now = clock.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _timer = Timer(nextMinute.difference(now), () {
      if (!mounted) {
        return;
      }
      setState(() => _now = clock.now());
      _scheduleNextTick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(_now),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return Text(
      text,
      style: AppTextStyles.appBarTitle.copyWith(color: AppColors.primary),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.outlineVariant.withValues(alpha: 0.3),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.icon, this.color = AppColors.primary});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Icon(icon, color: color, size: 12),
    );
  }
}

/// Ignition and input voltage of the car power supply; red when it does not
/// answer or is about to switch off.
class PowerSupplyIndicator extends StatelessWidget {
  const PowerSupplyIndicator({required this.status, super.key});

  final PowerSupplyStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!status.connected) {
      return Semantics(
        label: l10n.text(AppTextKey.powerSupplyNotResponding),
        child: const _StatusIcon(icon: Icons.power_off, color: AppColors.error),
      );
    }
    final color = status.switchingOff ? AppColors.error : AppColors.primary;
    final volts = status.inputVolts;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusIcon(
          icon: status.ignition == false ? Icons.key_off : Icons.key,
          color: color,
        ),
        if (volts != null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '${volts.toStringAsFixed(1).replaceAll('.', l10n.decimalSeparator)} V',
              style: AppTextStyles.appBarTitle.copyWith(
                color: color,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

/// Notice under the top bar while the power supply is switching off. The
/// backend does not shut the Pi down yet, so it only says what is coming.
class PowerSupplyNotice extends StatelessWidget {
  const PowerSupplyNotice({required this.status, super.key});

  final PowerSupplyStatus status;

  @override
  Widget build(BuildContext context) {
    if (!status.switchingOff) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final text = status.ignition == false
        ? l10n.text(AppTextKey.powerSupplyIgnitionOff)
        : l10n.text(AppTextKey.powerSupplySwitchingOff);
    return Container(
      width: double.infinity,
      color: AppColors.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.power_settings_new,
            color: AppColors.onErrorContainer,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
