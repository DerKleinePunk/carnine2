/// What a control does: a switch (on/off) or a slider (a level).
enum ControlKind { toggle, slider }

/// One control as the backend lists it (`ControlService.GetControls`): the
/// items of the Technik page, in the order of the configuration.
class ControlDefinition {
  const ControlDefinition({
    required this.id,
    required this.name,
    required this.kind,
    this.min = 0,
    this.max = 100,
  });

  final String id;

  /// What the user called it, e.g. "Innenlicht". Shown as it is, never
  /// translated.
  final String name;
  final ControlKind kind;

  /// The range of a slider; unused for a switch.
  final int min;
  final int max;
}

/// The state of one control (`ControlService.StreamControlStates`).
class ControlValue {
  const ControlValue({
    required this.id,
    required this.isAvailable,
    this.isOn,
    this.level,
  });

  final String id;

  /// The module behind it answers. Without it the control is greyed out and
  /// cannot be used; it comes back by itself.
  final bool isAvailable;

  /// For a switch.
  final bool? isOn;

  /// For a slider.
  final int? level;
}
