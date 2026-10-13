import 'dart:async';

/// Trade fair mode (#128): calls [onIdle] when nobody has touched the screen
/// for [after]. Every [touch] starts the time again.
///
/// Runs only while [isEnabled] says so - the backend reports the trade fair
/// mode, and without it nothing happens. After [onIdle] the time starts again
/// with the next touch or [sync]; a caller that wants another minute at once
/// (someone is in the middle of typing) calls [restart].
class IdleReturn {
  IdleReturn({
    required this.after,
    required this.isEnabled,
    required this.onIdle,
  });

  final Duration after;
  final bool Function() isEnabled;
  final void Function() onIdle;

  Timer? _timer;

  bool get isRunning => _timer != null;

  /// A touch: the time starts again.
  void touch() => restart();

  /// Starts the time again, or stops it when the mode is off.
  void restart() {
    _timer?.cancel();
    _timer = null;
    if (!isEnabled()) {
      return;
    }
    _timer = Timer(after, _fire);
  }

  /// The mode may have switched on or off: starts the timer once it is on,
  /// and stops it once it is off. A running timer is not restarted.
  void sync() {
    if (!isEnabled()) {
      _timer?.cancel();
      _timer = null;
    } else if (_timer == null) {
      restart();
    }
  }

  void _fire() {
    _timer = null;
    if (isEnabled()) {
      onIdle();
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
