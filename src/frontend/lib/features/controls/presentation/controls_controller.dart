import 'dart:async';

import 'package:carnine_frontend/features/controls/data/controls_repository.dart';
import 'package:carnine_frontend/features/controls/domain/control.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

enum ControlsStatus { loading, ready, offline }

/// State of the Technik page: the controls the backend lists, their states
/// from the stream, and the changes sent back (#86).
///
/// The state shown is the one from the stream; a reply to a change only
/// makes it appear sooner. A slider keeps its own value while it is dragged,
/// so the thumb does not jump back under the finger, and sends it throttled
/// and once more when it is let go.
class ControlsController extends ChangeNotifier {
  ControlsController({
    required this._repository,
    this.sliderThrottle = const Duration(milliseconds: 150),
    this.retryDelays = const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 5),
    ],
    Logger? logger,
  }) : _logger = logger ?? Logger('ControlsController');

  /// A slider sends at most once in this time while it is dragged.
  final Duration sliderThrottle;

  /// Pauses between attempts to reach the backend again; the last one repeats.
  final List<Duration> retryDelays;

  static const Duration _errorDuration = Duration(seconds: 4);

  final ControlsRepository _repository;
  final Logger _logger;

  ControlsStatus _status = ControlsStatus.loading;
  List<ControlDefinition> _controls = const [];
  final Map<String, ControlValue> _values = {};
  final Map<String, int> _drafts = {};
  final Map<String, int> _lastSent = {};
  final Map<String, Timer> _throttles = {};
  StreamSubscription<ControlValue>? _subscription;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _outage = false;
  AppTextKey? _errorKey;
  Timer? _errorTimer;
  bool _disposed = false;

  ControlsStatus get status => _status;

  /// In the order of the configuration.
  List<ControlDefinition> get controls => _controls;

  /// Why the last change failed, shown briefly.
  AppTextKey? get errorKey => _errorKey;

  /// The module behind [id] answers. Not before its state has arrived.
  bool isAvailable(String id) => _values[id]?.isAvailable ?? false;

  bool isOn(String id) => _values[id]?.isOn ?? false;

  /// What a slider shows: the value being dragged, else the one from the
  /// stream, else the bottom of its range.
  int levelOf(ControlDefinition control) =>
      _drafts[control.id] ?? _values[control.id]?.level ?? control.min;

  /// Loads the controls and starts listening to their states.
  Future<void> start() => _connect();

  /// The retry button: try again now.
  Future<void> retryNow() {
    _status = ControlsStatus.loading;
    notifyListeners();
    return _connect();
  }

  void dismissError() {
    if (_errorKey == null) {
      return;
    }
    _errorTimer?.cancel();
    _errorKey = null;
    notifyListeners();
  }

  /// Switches [id] to the opposite of what it shows.
  Future<void> toggle(String id) async {
    if (!isAvailable(id)) {
      return;
    }
    final on = !isOn(id);
    await _send(() => _repository.setOn(id, on: on));
  }

  /// A slider is being dragged to [level]: shown at once, sent throttled.
  void dragLevel(String id, int level) {
    _drafts[id] = level;
    notifyListeners();
    _throttles[id] ??= Timer(sliderThrottle, () {
      _throttles.remove(id);
      final draft = _drafts[id];
      if (draft != null && draft != _lastSent[id]) {
        unawaited(_sendLevel(id, draft));
      }
    });
  }

  /// A slider was let go at [level]: sent for good.
  Future<void> commitLevel(String id, int level) async {
    _throttles.remove(id)?.cancel();
    _drafts[id] = level;
    await _sendLevel(id, level);
    _drafts.remove(id);
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _sendLevel(String id, int level) async {
    _lastSent[id] = level;
    await _send(() => _repository.setLevel(id, level: level));
  }

  Future<void> _send(Future<ControlValue> Function() call) async {
    try {
      final reply = await call();
      if (_disposed) {
        return;
      }
      _values[reply.id] = reply;
      notifyListeners();
    } on Object catch (error) {
      // The state from the stream is the one that counts; the user only
      // hears that it did not work.
      _logger.warning('Changing a control failed: $error');
      if (_disposed) {
        return;
      }
      _errorKey = AppTextKey.mediaCommandFailed;
      _errorTimer?.cancel();
      _errorTimer = Timer(_errorDuration, dismissError);
      notifyListeners();
    }
  }

  Future<void> _connect() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    try {
      final controls = await _repository.loadControls();
      if (_disposed) {
        return;
      }
      _controls = controls;
      await _subscription?.cancel();
      _subscription = _repository.controlStates().listen(
        _onValue,
        onError: _goOffline,
        onDone: () => _goOffline('stream closed'),
        cancelOnError: true,
      );
      if (_outage) {
        _outage = false;
        _logger.info('Controls are back');
      }
      _attempt = 0;
      _status = ControlsStatus.ready;
      notifyListeners();
    } on Object catch (error) {
      _goOffline(error);
    }
  }

  void _onValue(ControlValue value) {
    _values[value.id] = value;
    notifyListeners();
  }

  /// The backend is away: say so, and try again with growing pauses.
  void _goOffline(Object reason) {
    if (_disposed) {
      return;
    }
    if (!_outage) {
      _outage = true;
      _logger.warning('Controls lost, retrying: $reason');
    }
    unawaited(_subscription?.cancel());
    _subscription = null;
    for (final timer in _throttles.values) {
      timer.cancel();
    }
    _throttles.clear();
    _drafts.clear();
    _status = ControlsStatus.offline;
    notifyListeners();

    final index = _attempt < retryDelays.length
        ? _attempt
        : retryDelays.length - 1;
    _attempt++;
    _retryTimer?.cancel();
    _retryTimer = Timer(retryDelays[index], () => unawaited(_connect()));
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _errorTimer?.cancel();
    for (final timer in _throttles.values) {
      timer.cancel();
    }
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
