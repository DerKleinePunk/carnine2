import 'dart:async';

import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

/// Compact top bar with system indicators and the time of day.
class CarnineTopBar extends StatelessWidget {
  const CarnineTopBar({super.key});

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
  const _StatusIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Icon(icon, color: AppColors.primary, size: 12),
    );
  }
}
