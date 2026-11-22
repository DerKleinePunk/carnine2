/// The installation values of the expert page (#138, #207): set once per
/// car, kept by the backend in `config.d/99-ui.toml`. The page knows no key
/// itself; it builds its fields from what the backend lists.
library;

/// How a value is entered.
enum InstallValueKind {
  /// A switch, "true" or "false".
  boolean,

  /// A whole number between [InstallValue.min] and [InstallValue.max].
  integer,

  /// One of [InstallValue.choices].
  choice,

  /// Free text up to [InstallValue.maxLength].
  text,

  /// One of the sound cards in [InstallValue.choices], or the system's
  /// default (= reset).
  soundCard,

  /// A kind this frontend does not know yet: shown, not editable.
  unknown,
}

class InstallValueChoice {
  const InstallValueChoice({required this.value, required this.label});

  final String value;
  final String label;
}

/// One value, with all the page needs to show and change it. Heading, label
/// and help come from the backend, in German.
class InstallValue {
  const InstallValue({
    required this.key,
    required this.group,
    required this.label,
    required this.kind,
    this.help = '',
    this.min = 0,
    this.max = 0,
    this.unit = '',
    this.maxLength = 0,
    this.choices = const [],
    this.defaultValue = '',
    this.optional = false,
    this.value = '',
    this.origin = '',
    this.restartPending = false,
  });

  /// Dotted key as in the configuration file, e.g. "reverse_gear.gpio_line".
  final String key;
  final String group;
  final String label;
  final String help;
  final InstallValueKind kind;
  final int min;
  final int max;
  final String unit;
  final int maxLength;
  final List<InstallValueChoice> choices;

  /// What applies without any file setting it; empty when it is then unset.
  final String defaultValue;

  /// May be unset: it can be reset, and then nothing sets it.
  final bool optional;

  /// What the configuration files say, as text; the default when none does.
  final String value;

  /// The file that sets the value; empty for the default.
  final String origin;

  /// The value differs from what the running backend uses.
  final bool restartPending;

  /// No file sets it: the default applies.
  bool get isDefault => origin.isEmpty;
}

class InstallValues {
  const InstallValues({
    required this.settings,
    this.restartRequired = false,
    this.uiDropInError = '',
    this.uiDropInPath = '',
  });

  final List<InstallValue> settings;

  /// Some value waits for the backend to start again.
  final bool restartRequired;

  /// Why the backend left out the page's file at start; empty when it did
  /// not. The values from before the file are active then.
  final String uiDropInError;

  /// Where the page's values are written.
  final String uiDropInPath;
}

/// A change to send: a new [value], or [reset] to take the value out of the
/// page's file.
class InstallValueChange {
  const InstallValueChange.set(this.key, String this.value) : reset = false;

  const InstallValueChange.reset(this.key) : value = null, reset = true;

  final String key;
  final String? value;
  final bool reset;
}

/// Why loading or saving did not go through.
enum InstallValuesFailure {
  /// The backend did not answer.
  unreachable,

  /// The exit password was wrong (`PERMISSION_DENIED`).
  wrongPassword,

  /// A value is wrong, or the configuration would be invalid with it
  /// (`INVALID_ARGUMENT`); nothing was saved. [InstallValuesException.message]
  /// says why, as the backend wrote it.
  rejected,

  /// Anything else.
  failed,
}

class InstallValuesException implements Exception {
  const InstallValuesException(this.failure, [this.message = '']);

  final InstallValuesFailure failure;

  /// The backend's reason: shown for [InstallValuesFailure.rejected], else
  /// for the log only.
  final String message;

  @override
  String toString() => 'InstallValuesException(${failure.name}): $message';
}

/// Where the expert page reads and saves the installation values.
abstract interface class InstallValuesStore {
  /// Reading needs no password. Throws an [InstallValuesException].
  Future<InstallValues> loadInstallSettings();

  /// Saves [changes] with the exit [password] and returns the values as they
  /// are then. Throws an [InstallValuesException]; nothing is saved then.
  Future<InstallValues> saveInstallSettings({
    required String password,
    required List<InstallValueChange> changes,
  });
}
