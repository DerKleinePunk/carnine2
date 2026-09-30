import 'dart:async';

/// Asks the backend every [interval] whether it still answers (#58).
///
/// A backend that hangs (deadlock, `kill -STOP`) keeps its socket open, so
/// the streams on it neither deliver nor fail. The HTTP/2 keepalive does not
/// help: grpc-dart answers a missed ping with an orderly `finish()`, which
/// waits for the very streams that no longer move. Only a call with a
/// deadline notices. [check] is that call; it also gets [timeout] here, so a
/// check that never returns counts as a failure too.
///
/// The first failure calls [onFailure] once and stops the heartbeat;
/// [start] it again once the connection is back.
class BackendHeartbeat {
  BackendHeartbeat({
    required this.check,
    required this.onFailure,
    this.interval = defaultInterval,
    this.timeout = defaultTimeout,
  });

  static const defaultInterval = Duration(seconds: 5);
  static const defaultTimeout = Duration(seconds: 3);

  final Future<void> Function() check;
  final void Function(Object error) onFailure;
  final Duration interval;
  final Duration timeout;

  Timer? _timer;
  int _generation = 0;

  bool get isRunning => _timer != null;

  void start() {
    stop();
    _schedule(_generation);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _generation++;
  }

  void _schedule(int generation) {
    _timer = Timer(interval, () => unawaited(_beat(generation)));
  }

  /// One check. The next one is only scheduled once this one is done, so a
  /// slow backend never gets overlapping checks.
  Future<void> _beat(int generation) async {
    try {
      await check().timeout(timeout);
    } catch (error) {
      if (generation == _generation) {
        stop();
        onFailure(error);
      }
      return;
    }
    if (generation == _generation) {
      _schedule(generation);
    }
  }
}
