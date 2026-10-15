/// The brightness of the display backlight as the backend reports it
/// (`SystemService.GetDisplayBrightness`, #102).
class DisplayBrightnessSetting {
  const DisplayBrightnessSetting({
    required this.configured,
    required this.available,
    required this.percent,
  });

  /// The display is modified for it (`[display.backlight]`); without that
  /// there is nothing to set, and the options show it as not set up.
  final bool configured;

  /// The PWM channel can be driven now; `false` while there is no overlay or
  /// chip. The slider is greyed out then.
  final bool available;

  /// 0 to 100. 0 is the darkest level the backend allows, never black.
  final int percent;

  /// A display with a backlight that can be set.
  bool get isUsable => configured && available;
}

/// Where the options get the display brightness from and send it to. The
/// backend keeps it over restarts; the frontend stores nothing.
abstract interface class DisplayBrightnessStore {
  Future<DisplayBrightnessSetting> loadDisplayBrightness();

  /// Sets [percent] and returns the state in effect. Fails with the backend's
  /// error when there is no backlight to set or the channel is not reachable.
  Future<DisplayBrightnessSetting> saveDisplayBrightness(int percent);
}
