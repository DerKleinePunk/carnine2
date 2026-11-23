import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/scheduler.dart' show TimingsCallback;
import 'package:logging/logging.dart';

/// Says when the first frame is on screen, so that systemd, Plymouth and the
/// amplifier relay can be told the UI is ready (#37).
///
/// A [FrameTiming] is reported only after the frame was rasterized and
/// handed to the embedder, so the first one is the earliest point at which
/// the picture is really there. Under flutter-pi a DRM commit could fail
/// silently, which is why frames used to be forced and five timings waited
/// for (ADR-019); ivi-homescreen does not need that any more.
///
/// [maxWait] is the safety net: if no timing comes, readiness is reported
/// anyway, well before the unit's `TimeoutStartSec`. [onReady] runs exactly
/// once.
class UiReadyDetector {
  UiReadyDetector({
    required this.addTimingsCallback,
    required this.removeTimingsCallback,
    required this.onReady,
    this.maxWait = defaultMaxWait,
    Stopwatch? stopwatch,
    Logger? logger,
  }) : _stopwatch = stopwatch ?? Stopwatch(),
       _logger = logger ?? Logger('UiReadiness');

  static const Duration defaultMaxWait = Duration(seconds: 5);

  final void Function(TimingsCallback) addTimingsCallback;
  final void Function(TimingsCallback) removeTimingsCallback;
  final void Function() onReady;
  final Duration maxWait;
  final Stopwatch _stopwatch;
  final Logger _logger;

  Timer? _maxWaitTimer;
  bool _started = false;
  bool _finished = false;

  bool get finished => _finished;

  void start() {
    if (_started) return;
    _started = true;
    _stopwatch.start();
    addTimingsCallback(_onTimings);
    _maxWaitTimer = Timer(maxWait, () => _finish(byFrame: false));
  }

  void _onTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    _finish(byFrame: true);
  }

  void _finish({required bool byFrame}) {
    if (_finished) return;
    _finished = true;
    removeTimingsCallback(_onTimings);
    _maxWaitTimer?.cancel();
    final elapsed = _stopwatch.elapsedMilliseconds;
    if (byFrame) {
      _logger.info('UI ready: first frame on screen after $elapsed ms');
    } else {
      _logger.warning(
        'UI ready: no frame timing within ${maxWait.inSeconds} s, '
        'reporting anyway',
      );
    }
    onReady();
  }
}
