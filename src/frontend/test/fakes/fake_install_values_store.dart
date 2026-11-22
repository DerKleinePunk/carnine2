import 'dart:async';

import 'package:carnine_frontend/features/settings/data/install_values_store.dart';

/// Hand-written [InstallValuesStore] for tests: the backend's expert page in
/// memory. [saves] records every save; a save applies its changes like the
/// backend, unless [saveError] is set. Its password is [password].
class FakeInstallValuesStore implements InstallValuesStore {
  FakeInstallValuesStore({
    List<InstallValue>? values,
    this.password = '4321',
    this.uiDropInError = '',
    this.restartRequired = false,
  }) : values = values ?? sampleInstallValues();

  List<InstallValue> values;
  String password;
  String uiDropInError;
  bool restartRequired;

  /// Thrown by the next loads while set.
  Object? loadError;

  /// Thrown by the next save, once.
  InstallValuesException? saveError;

  /// Holds a save until completed.
  Completer<void>? saveGate;

  int loads = 0;
  final List<({String password, List<InstallValueChange> changes})> saves = [];

  InstallValues get _current => InstallValues(
    settings: values,
    restartRequired: restartRequired,
    uiDropInError: uiDropInError,
    uiDropInPath: '/etc/carnine/config.d/99-ui.toml',
  );

  @override
  Future<InstallValues> loadInstallSettings() async {
    loads++;
    final failure = loadError;
    if (failure != null) {
      throw failure;
    }
    return _current;
  }

  @override
  Future<InstallValues> saveInstallSettings({
    required String password,
    required List<InstallValueChange> changes,
  }) async {
    saves.add((password: password, changes: changes));
    await saveGate?.future;
    final failure = saveError;
    if (failure != null) {
      saveError = null;
      throw failure;
    }
    if (password != this.password) {
      throw const InstallValuesException(InstallValuesFailure.wrongPassword);
    }
    values = [
      for (final value in values)
        _applied(value, [
          for (final change in changes)
            if (change.key == value.key) change,
        ]),
    ];
    restartRequired = true;
    return _current;
  }

  /// What the backend reports after saving: set in 99-ui.toml, waiting for
  /// a restart; a reset value back to its default.
  static InstallValue _applied(
    InstallValue value,
    List<InstallValueChange> changes,
  ) {
    if (changes.isEmpty) {
      return value;
    }
    final change = changes.last;
    return _copy(
      value,
      text: change.value ?? value.defaultValue,
      origin: change.reset ? '' : '/etc/carnine/config.d/99-ui.toml',
    );
  }

  static InstallValue _copy(
    InstallValue value, {
    required String text,
    required String origin,
  }) => InstallValue(
    key: value.key,
    group: value.group,
    label: value.label,
    help: value.help,
    kind: value.kind,
    min: value.min,
    max: value.max,
    unit: value.unit,
    maxLength: value.maxLength,
    choices: value.choices,
    defaultValue: value.defaultValue,
    optional: value.optional,
    value: text,
    origin: origin,
    restartPending: true,
  );
}

/// Values like the backend's schema of 0.22.0, with a choice of five for the
/// list dialog.
List<InstallValue> sampleInstallValues() => const [
  InstallValue(
    key: 'reverse_gear.source',
    group: 'Rückwärtsgang',
    label: 'Quelle',
    help: 'Woher das Backend den Rückwärtsgang liest.',
    kind: InstallValueKind.choice,
    choices: [
      InstallValueChoice(value: 'none', label: 'Keine'),
      InstallValueChoice(value: 'gpio', label: 'GPIO'),
      InstallValueChoice(value: 'demo', label: 'Demo'),
    ],
    defaultValue: 'none',
    value: 'none',
  ),
  InstallValue(
    key: 'reverse_gear.gpio_line',
    group: 'Rückwärtsgang',
    label: 'GPIO-Leitung',
    help: 'Nummer der Leitung auf dem Chip.',
    kind: InstallValueKind.integer,
    max: 511,
    optional: true,
  ),
  InstallValue(
    key: 'reverse_gear.active_low',
    group: 'Rückwärtsgang',
    label: 'Aktiv bei Masse',
    help: 'Der Gang ist drin, wenn die Leitung auf Masse liegt.',
    kind: InstallValueKind.boolean,
    defaultValue: 'true',
    value: 'true',
  ),
  InstallValue(
    key: 'reverse_gear.gpio_chip',
    group: 'Rückwärtsgang',
    label: 'GPIO-Chip',
    help: 'Gerätedatei des GPIO-Chips.',
    kind: InstallValueKind.text,
    maxLength: 64,
    defaultValue: '/dev/gpiochip0',
    value: '/dev/gpiochip0',
  ),
  InstallValue(
    key: 'audio.output_card',
    group: 'Tonausgabe',
    label: 'Ausgang',
    help: 'Soundkarte, an der die Lautsprecher hängen.',
    kind: InstallValueKind.soundCard,
    choices: [
      InstallValueChoice(value: 'Headphones', label: 'Headphones'),
      InstallValueChoice(value: 'vc4hdmi0', label: 'vc4hdmi0'),
    ],
    optional: true,
  ),
  InstallValue(
    key: 'audio.rear_percent',
    group: 'Tonausgabe',
    label: 'Pegel hinten',
    help: 'Lautstärke der hinteren Lautsprecher im Verhältnis zu vorn.',
    kind: InstallValueKind.integer,
    max: 100,
    unit: '%',
    defaultValue: '100',
    value: '30',
    origin: '/etc/carnine/config.d/99-ui.toml',
    optional: true,
    restartPending: true,
  ),
  InstallValue(
    key: 'audio.test_many',
    group: 'Tonausgabe',
    label: 'Viele',
    help: 'Fünf Möglichkeiten, für die Liste.',
    kind: InstallValueKind.choice,
    choices: [
      InstallValueChoice(value: 'a', label: 'Eins'),
      InstallValueChoice(value: 'b', label: 'Zwei'),
      InstallValueChoice(value: 'c', label: 'Drei'),
      InstallValueChoice(value: 'd', label: 'Vier'),
      InstallValueChoice(value: 'e', label: 'Fünf'),
    ],
    defaultValue: 'a',
    value: 'a',
  ),
  InstallValue(
    key: 'power_supply.enabled',
    group: 'Netzteil',
    label: 'Netzteil angeschlossen',
    help: 'Das Backend spricht mit dem Kfz-Netzteil.',
    kind: InstallValueKind.boolean,
    defaultValue: 'false',
    value: 'false',
  ),
];
