import 'dart:async';

import 'package:carnine_frontend/features/settings/data/install_values_store.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

enum InstallValuesStatus { loading, ready, offline }

/// What a save ended with.
enum InstallSaveOutcome { saved, wrongPassword, rejected, unreachable, failed }

/// The expert page (#207): the installation values the backend lists, the
/// changes collected on the page, and saving them with the exit password.
///
/// Nothing is sent before "Speichern"; then only the changed keys go, all in
/// one call, so values that belong together (source GPIO and its line) are
/// checked together.
class InstallValuesController extends ChangeNotifier {
  InstallValuesController({
    required this._store,
    required this._password,
    this.messageDuration = const Duration(seconds: 4),
    Logger? logger,
  }) : _logger = logger ?? Logger('InstallValuesController');

  /// How long "Gespeichert" stays.
  final Duration messageDuration;

  final InstallValuesStore _store;
  final Logger _logger;
  String _password;

  InstallValuesStatus _status = InstallValuesStatus.loading;
  InstallValues _values = const InstallValues(settings: []);
  final Map<String, InstallValueChange> _drafts = {};
  bool _saving = false;
  InstallSaveOutcome? _outcome;
  String _rejection = '';
  Timer? _messageTimer;
  bool _disposed = false;

  InstallValuesStatus get status => _status;
  InstallValues get values => _values;
  bool get isSaving => _saving;

  /// How the last save went, until the next change; "saved" only for a while.
  InstallSaveOutcome? get outcome => _outcome;

  /// The backend's reason when the last save was [InstallSaveOutcome.rejected].
  String get rejection => _rejection;

  bool get hasChanges => _drafts.isNotEmpty;
  int get changeCount => _drafts.length;

  bool isChanged(String key) => _drafts.containsKey(key);

  /// The value is to be reset when saved.
  bool isResetPending(String key) => _drafts[key]?.reset ?? false;

  /// What the row shows: the changed value, else what the files say. A value
  /// to be reset shows its default.
  String shownValue(InstallValue value) {
    final draft = _drafts[value.key];
    if (draft == null) {
      return value.value;
    }
    return draft.value ?? value.defaultValue;
  }

  /// The headings in the order the backend lists them, each with its values.
  List<(String, List<InstallValue>)> get groups {
    final groups = <String, List<InstallValue>>{};
    for (final value in _values.settings) {
      groups.putIfAbsent(value.group, () => []).add(value);
    }
    return [for (final entry in groups.entries) (entry.key, entry.value)];
  }

  Future<void> load() async {
    try {
      final values = await _store.loadInstallSettings();
      if (_disposed) {
        return;
      }
      _values = values;
      _status = InstallValuesStatus.ready;
    } on InstallValuesException catch (error) {
      _logger.warning('Installation values not available: $error');
      if (_disposed) {
        return;
      }
      // An answer already on screen stays; only a first load goes offline.
      if (_status != InstallValuesStatus.ready) {
        _status = InstallValuesStatus.offline;
      }
    }
    notifyListeners();
  }

  /// [text] for [value]: a change, or none when it is what the files say.
  void change(InstallValue value, String text) {
    if (text == value.value) {
      // Back to what the files say (or the default): nothing to write.
      _drafts.remove(value.key);
    } else {
      _drafts[value.key] = InstallValueChange.set(value.key, text);
    }
    _clearOutcome();
    notifyListeners();
  }

  /// Takes [value] out of the page's file when saved.
  void reset(InstallValue value) {
    if (value.isDefault) {
      _drafts.remove(value.key);
    } else {
      _drafts[value.key] = InstallValueChange.reset(value.key);
    }
    _clearOutcome();
    notifyListeners();
  }

  void discard() {
    if (_drafts.isEmpty) {
      return;
    }
    _drafts.clear();
    _clearOutcome();
    notifyListeners();
  }

  /// A new password after the backend refused the one given at the start.
  void updatePassword(String password) => _password = password;

  /// Sends the changed keys. Nothing is saved unless the outcome is
  /// [InstallSaveOutcome.saved]; the changes stay on the page then.
  Future<InstallSaveOutcome> save() async {
    if (_saving || _drafts.isEmpty) {
      return _outcome ?? InstallSaveOutcome.saved;
    }
    _saving = true;
    _clearOutcome();
    notifyListeners();

    final changes = _drafts.values.toList();
    InstallSaveOutcome outcome;
    try {
      final values = await _store.saveInstallSettings(
        password: _password,
        changes: changes,
      );
      _logger.info(
        'Saved installation values: '
        '${changes.map((change) => change.key).join(', ')}',
      );
      _values = values;
      _drafts.clear();
      outcome = InstallSaveOutcome.saved;
    } on InstallValuesException catch (error) {
      _logger.warning('Saving installation values failed: $error');
      outcome = switch (error.failure) {
        InstallValuesFailure.wrongPassword => InstallSaveOutcome.wrongPassword,
        InstallValuesFailure.rejected => InstallSaveOutcome.rejected,
        InstallValuesFailure.unreachable => InstallSaveOutcome.unreachable,
        InstallValuesFailure.failed => InstallSaveOutcome.failed,
      };
      _rejection = error.message;
    }
    if (_disposed) {
      return outcome;
    }
    _saving = false;
    _outcome = outcome;
    if (outcome == InstallSaveOutcome.saved) {
      _messageTimer = Timer(messageDuration, () {
        _clearOutcome();
        notifyListeners();
      });
    }
    notifyListeners();
    return outcome;
  }

  void _clearOutcome() {
    _messageTimer?.cancel();
    _messageTimer = null;
    _outcome = null;
    _rejection = '';
  }

  @override
  void dispose() {
    _disposed = true;
    _messageTimer?.cancel();
    super.dispose();
  }
}
