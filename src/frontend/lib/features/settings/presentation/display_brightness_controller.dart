import 'dart:async';

import 'package:carnine_frontend/features/settings/data/display_brightness_store.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

enum DisplayBrightnessStatus { loading, ready, offline }

/// State of the display brightness (#102): what the backend reports and the
/// slider on "Geräte → Display". The display changes while the thumb is
/// dragged, so the level is sent about every [sendInterval] and once more
/// when it is let go - the same rhythm as the sliders of the Technik page.
class DisplayBrightnessController extends ChangeNotifier {
  DisplayBrightnessController({
    required this._store,
    this.sendInterval = const Duration(milliseconds: 150),
    Logger? logger,
  }) : _logger = logger ?? Logger('DisplayBrightnessController');

  static const _errorDuration = Duration(seconds: 4);

  final DisplayBrightnessStore _store;
  final Duration sendInterval;
  final Logger _logger;

  DisplayBrightnessStatus _status = DisplayBrightnessStatus.loading;
  DisplayBrightnessSetting? _setting;
  int? _draft;
  int? _lastSent;
  Timer? _sendTimer;
  bool _sending = false;
  AppTextKey? _errorKey;
  Timer? _errorTimer;
  bool _disposed = false;

  DisplayBrightnessStatus get status => _status;

  /// What the backend reported last; `null` before the first answer.
  DisplayBrightnessSetting? get setting => _setting;

  /// The backend answered, and this display has no backlight to set.
  bool get isNotConfigured =>
      _status == DisplayBrightnessStatus.ready && _setting?.configured == false;

  /// A backlight that can be set now.
  bool get isUsable =>
      _status == DisplayBrightnessStatus.ready && (_setting?.isUsable ?? false);

  /// Brightness as shown: the value being dragged, else the saved one.
  int get percent => _draft ?? _setting?.percent ?? 100;

  /// Why the last change failed, shown briefly.
  AppTextKey? get errorKey => _errorKey;

  /// Asks the backend. Also the retry after it was away.
  Future<void> load() async {
    if (_setting == null) {
      _status = DisplayBrightnessStatus.loading;
      notifyListeners();
    }
    try {
      final setting = await _store.loadDisplayBrightness();
      if (_disposed) {
        return;
      }
      _setting = setting;
      _lastSent = setting.percent;
      _status = DisplayBrightnessStatus.ready;
    } on Object catch (error) {
      _logger.warning('Display brightness not available: $error');
      if (_disposed) {
        return;
      }
      _status = DisplayBrightnessStatus.offline;
    }
    notifyListeners();
  }

  /// While the thumb is dragged: shown at once, sent every [sendInterval].
  void drag(int percent) {
    if (!isUsable) {
      return;
    }
    _draft = percent;
    notifyListeners();
    _sendTimer ??= Timer(sendInterval, () {
      _sendTimer = null;
      unawaited(_sendLatest());
    });
  }

  /// The thumb is let go: the last level goes out at once.
  Future<void> commit(int percent) {
    if (!isUsable) {
      return Future.value();
    }
    _sendTimer?.cancel();
    _sendTimer = null;
    _draft = percent;
    notifyListeners();
    return _sendLatest();
  }

  void dismissError() {
    if (_errorKey == null) {
      return;
    }
    _errorTimer?.cancel();
    _errorKey = null;
    notifyListeners();
  }

  /// Sends the newest level, one call at a time; a level that came in while
  /// one was on its way follows it.
  Future<void> _sendLatest() async {
    if (_sending) {
      return;
    }
    _sending = true;
    try {
      while (!_disposed) {
        final level = _draft;
        if (level == null || level == _lastSent) {
          break;
        }
        try {
          _setting = await _store.saveDisplayBrightness(level);
          _lastSent = level;
        } on Object catch (error) {
          _logger.warning('Setting the display brightness failed: $error');
          // The slider goes back to what the backend has.
          _draft = null;
          _lastSent = _setting?.percent;
          _showError();
          break;
        }
      }
      if (!_disposed && _draft == _lastSent) {
        _draft = null;
      }
    } finally {
      _sending = false;
    }
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _showError() {
    _errorKey = AppTextKey.mediaCommandFailed;
    _errorTimer?.cancel();
    _errorTimer = Timer(_errorDuration, dismissError);
  }

  @override
  void dispose() {
    _disposed = true;
    _sendTimer?.cancel();
    _errorTimer?.cancel();
    super.dispose();
  }
}
