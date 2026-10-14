import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';

/// Builds its child with the time of day and builds it again at every change
/// of the minute - for the clock of the top bar and of the start page.
class MinuteClock extends StatefulWidget {
  const MinuteClock({required this.builder, super.key});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<MinuteClock> createState() => _MinuteClockState();
}

class _MinuteClockState extends State<MinuteClock> {
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
  Widget build(BuildContext context) => widget.builder(context, _now);
}
