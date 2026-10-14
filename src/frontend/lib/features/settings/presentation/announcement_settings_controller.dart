import 'dart:async';

import 'package:carnine_frontend/features/settings/data/announcement_settings_store.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

enum AnnouncementSettingsStatus { loading, ready, offline }

/// State of the "Ansagen" page (#110): switch, loudness and music level of
/// the spoken turn instructions. The backend keeps and saves them, so every
/// change goes there at once; a slider sends when it is let go.
class AnnouncementSettingsController extends ChangeNotifier {
  AnnouncementSettingsController({required this._store, Logger? logger})
    : _logger = logger ?? Logger('AnnouncementSettingsController');

  /// What the test button speaks. German on purpose: the installed voices are
  /// German, whatever language the display is in.
  static const String testSentence = 'In 300 Metern rechts abbiegen.';

  static const _errorDuration = Duration(seconds: 4);

  final AnnouncementSettingsStore _store;
  final Logger _logger;

  AnnouncementSettingsStatus _status = AnnouncementSettingsStatus.loading;
  AnnouncementSettings? _settings;
  int? _volumeDraft;
  int? _musicDraft;
  bool _isTesting = false;
  AppTextKey? _errorKey;
  Timer? _errorTimer;
  bool _disposed = false;

  /// Changes are saved one after the other, so two cannot overtake each other.
  Future<void> _saving = Future<void>.value();

  AnnouncementSettingsStatus get status => _status;

  /// `null` until the settings are loaded.
  AnnouncementSettings? get settings => _settings;

  /// A voice is installed; without one nothing on the page works.
  bool get isAvailable => _settings?.available ?? false;
  bool get isEnabled => _settings?.enabled ?? false;
  bool get isTesting => _isTesting;
  bool get canTest => isAvailable && isEnabled && !_isTesting;

  /// Loudness as shown: the value being dragged, else the saved one.
  int get volume => _volumeDraft ?? _settings?.volumePercent ?? 0;

  /// Music level during an announcement as shown.
  int get musicUnder => _musicDraft ?? _settings?.musicUnderPercent ?? 0;

  /// Why the last change failed, shown briefly.
  AppTextKey? get errorKey => _errorKey;

  /// Loads the settings. Also the retry after the backend was away.
  Future<void> load() async {
    _status = AnnouncementSettingsStatus.loading;
    notifyListeners();

    try {
      final settings = await _store.loadAnnouncementSettings();
      if (_disposed) {
        return;
      }
      _settings = settings;
      _volumeDraft = null;
      _musicDraft = null;
      _status = AnnouncementSettingsStatus.ready;
    } on Object catch (error) {
      _logger.warning('Announcement settings not available: $error');
      if (_disposed) {
        return;
      }
      _status = AnnouncementSettingsStatus.offline;
    }
    notifyListeners();
  }

  Future<void> setEnabled({required bool enabled}) {
    if (!isAvailable || enabled == isEnabled) {
      return Future.value();
    }
    return _save(enabled: enabled);
  }

  /// While the thumb is dragged: shown at once, not sent.
  void dragVolume(int percent) {
    if (!isAvailable) {
      return;
    }
    _volumeDraft = percent;
    notifyListeners();
  }

  /// The thumb is let go: send it.
  Future<void> commitVolume(int percent) {
    if (!isAvailable) {
      return Future.value();
    }
    _volumeDraft = percent;
    notifyListeners();
    return _save(volumePercent: percent);
  }

  void dragMusicUnder(int percent) {
    if (!isAvailable) {
      return;
    }
    _musicDraft = percent;
    notifyListeners();
  }

  Future<void> commitMusicUnder(int percent) {
    if (!isAvailable) {
      return Future.value();
    }
    _musicDraft = percent;
    notifyListeners();
    return _save(musicUnderPercent: percent);
  }

  /// Speaks [testSentence], to hear loudness and the music's level.
  Future<void> playTest() async {
    if (!canTest) {
      return;
    }
    _isTesting = true;
    notifyListeners();
    try {
      await _store.announce(testSentence);
    } on Object catch (error) {
      _logger.warning('The test announcement failed: $error');
      _showError();
    } finally {
      if (!_disposed) {
        _isTesting = false;
        notifyListeners();
      }
    }
  }

  void dismissError() {
    if (_errorKey == null) {
      return;
    }
    _errorTimer?.cancel();
    _errorKey = null;
    notifyListeners();
  }

  Future<void> _save({
    bool? enabled,
    int? volumePercent,
    int? musicUnderPercent,
  }) {
    final done = _saving.then(
      (_) => _saveNow(
        enabled: enabled,
        volumePercent: volumePercent,
        musicUnderPercent: musicUnderPercent,
      ),
    );
    _saving = done;
    return done;
  }

  Future<void> _saveNow({
    bool? enabled,
    int? volumePercent,
    int? musicUnderPercent,
  }) async {
    if (_disposed) {
      return;
    }
    try {
      final saved = await _store.saveAnnouncementSettings(
        enabled: enabled,
        volumePercent: volumePercent,
        musicUnderPercent: musicUnderPercent,
      );
      if (_disposed) {
        return;
      }
      _settings = saved;
      _errorKey = null;
      // A slider that was moved on in the meantime keeps its newer value.
      if (volumePercent != null && _volumeDraft == volumePercent) {
        _volumeDraft = null;
      }
      if (musicUnderPercent != null && _musicDraft == musicUnderPercent) {
        _musicDraft = null;
      }
    } on Object catch (error) {
      _logger.warning('Saving the announcement settings failed: $error');
      if (_disposed) {
        return;
      }
      // The slider goes back to what the backend has.
      if (volumePercent != null && _volumeDraft == volumePercent) {
        _volumeDraft = null;
      }
      if (musicUnderPercent != null && _musicDraft == musicUnderPercent) {
        _musicDraft = null;
      }
      _showError();
    }
    notifyListeners();
  }

  void _showError() {
    if (_disposed) {
      return;
    }
    _errorKey = AppTextKey.mediaCommandFailed;
    _errorTimer?.cancel();
    _errorTimer = Timer(_errorDuration, dismissError);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _errorTimer?.cancel();
    super.dispose();
  }
}
