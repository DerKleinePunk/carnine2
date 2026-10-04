import 'dart:async';

import 'package:carnine_frontend/features/controls/data/controls_repository.dart';
import 'package:carnine_frontend/features/controls/domain/control.dart';

/// Hand-written [ControlsRepository] for tests: the backend with a few
/// controls in memory. [sets] records every change, e.g. `fan:level:70` or
/// `light:on`; [push], [breakStream] and [closeStream] play what the stream
/// does.
class FakeControlsRepository implements ControlsRepository {
  FakeControlsRepository({
    this.controls = const [],
    Map<String, ControlValue> values = const {},
  }) : values = {...values};

  List<ControlDefinition> controls;

  /// The state of each control; the stream starts with all of them.
  final Map<String, ControlValue> values;

  /// Thrown by [loadControls] while set.
  Object? loadError;

  /// Thrown by the next change, once.
  Object? setError;

  final List<String> sets = [];
  int loads = 0;
  int streamStarts = 0;
  StreamController<ControlValue>? _stream;

  @override
  Future<List<ControlDefinition>> loadControls() async {
    loads++;
    final failure = loadError;
    if (failure != null) {
      throw failure;
    }
    return controls;
  }

  @override
  Stream<ControlValue> controlStates() {
    late final StreamController<ControlValue> controller;
    controller = StreamController<ControlValue>(
      onListen: () {
        streamStarts++;
        values.values.forEach(controller.add);
      },
    );
    _stream = controller;
    return controller.stream;
  }

  /// A change of state arrives on the stream, and is kept for the next one.
  void push(ControlValue value) {
    values[value.id] = value;
    _stream?.add(value);
  }

  /// The connection breaks: the stream ends with an error.
  void breakStream() => _stream?.addError(StateError('connection lost'));

  /// The backend closes the stream.
  void closeStream() => unawaited(_stream?.close());

  @override
  Future<ControlValue> setOn(String id, {required bool on}) async {
    sets.add('$id:${on ? 'on' : 'off'}');
    final value = _change(id, isOn: on);
    return value;
  }

  @override
  Future<ControlValue> setLevel(String id, {required int level}) async {
    sets.add('$id:level:$level');
    return _change(id, level: level);
  }

  ControlValue _change(String id, {bool? isOn, int? level}) {
    final failure = setError;
    if (failure != null) {
      setError = null;
      throw failure;
    }
    final before = values[id];
    final value = ControlValue(
      id: id,
      isAvailable: before?.isAvailable ?? true,
      isOn: isOn ?? before?.isOn,
      level: level ?? before?.level,
    );
    values[id] = value;
    return value;
  }

  @override
  Future<void> dispose() async {}
}

/// Eight switches like the trade fair rig (#86), all on and reachable.
List<ControlDefinition> eightSwitches() => [
  for (var i = 1; i <= 8; i++)
    ControlDefinition(
      id: 'sw$i',
      name: 'Schalter $i',
      kind: ControlKind.toggle,
    ),
];

Map<String, ControlValue> allOff(Iterable<ControlDefinition> controls) => {
  for (final control in controls)
    control.id: ControlValue(
      id: control.id,
      isAvailable: true,
      isOn: control.kind == ControlKind.toggle ? false : null,
      level: control.kind == ControlKind.slider ? control.min : null,
    ),
};
