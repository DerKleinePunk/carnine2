import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';

/// Tells the backend, then systemd, that the UI is on screen.
///
/// The backend may still be starting: its unit is `Type=simple`, so the
/// frontend's `After=carnine-backend.service` only waits for the process,
/// not for the socket. A single failed attempt used to mean no READY at all,
/// and systemd killed the frontend after `TimeoutStartSec` (#54). While the
/// backend is unreachable this tries again with growing pauses, but gives up
/// after [giveUpAfter] so a backend that never comes still ends in a restart
/// by systemd, as before.
class UiReadinessReporter {
  UiReadinessReporter({
    required this.reportToBackend,
    required this.notifySystemd,
    this.retryDelays = defaultRetryDelays,
    this.giveUpAfter = defaultGiveUpAfter,
    Logger? logger,
  }) : _logger = logger ?? Logger('UiReadiness');

  /// The last one repeats.
  static const List<Duration> defaultRetryDelays = <Duration>[
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  /// Stays below the unit's `TimeoutStartSec=30s`, which also has to cover
  /// the frames waited for before reporting.
  static const Duration defaultGiveUpAfter = Duration(seconds: 20);

  final Future<void> Function() reportToBackend;
  final Future<void> Function() notifySystemd;
  final List<Duration> retryDelays;
  final Duration giveUpAfter;
  final Logger _logger;

  /// True once both the backend and systemd were told.
  Future<bool> report() async {
    var waited = Duration.zero;
    for (var attempt = 0; ; attempt++) {
      try {
        await reportToBackend();
        break;
      } on GrpcError catch (error, stackTrace) {
        if (error.code != StatusCode.unavailable || waited >= giveUpAfter) {
          _logger.severe('UI readiness handshake failed', error, stackTrace);
          return false;
        }
        if (attempt == 0) {
          _logger.info('Backend not reachable yet, retrying UI readiness');
        }
      } catch (error, stackTrace) {
        _logger.severe('UI readiness handshake failed', error, stackTrace);
        return false;
      }
      final delay =
          retryDelays[attempt < retryDelays.length
              ? attempt
              : retryDelays.length - 1];
      waited += delay;
      await Future<void>.delayed(delay);
    }
    _logger.info('UI readiness reported to backend');
    await notifySystemd();
    return true;
  }
}
