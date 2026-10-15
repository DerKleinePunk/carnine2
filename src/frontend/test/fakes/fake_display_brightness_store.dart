import 'dart:async';

import 'package:carnine_frontend/features/settings/data/display_brightness_store.dart';

/// Hand-written [DisplayBrightnessStore] for tests: the backend with a
/// display in memory. [saves] records every level sent.
class FakeDisplayBrightnessStore implements DisplayBrightnessStore {
  FakeDisplayBrightnessStore({
    this.configured = true,
    this.available = true,
    this.percent = 100,
  });

  bool configured;
  bool available;
  int percent;

  /// Thrown by loading while it is set, to play a backend that is away.
  Object? loadError;

  /// Thrown by the next save, once.
  Object? saveError;

  /// Holds a save until completed.
  Completer<void>? saveGate;

  int loads = 0;
  final List<int> saves = [];

  DisplayBrightnessSetting get _state => DisplayBrightnessSetting(
    configured: configured,
    available: available,
    percent: percent,
  );

  @override
  Future<DisplayBrightnessSetting> loadDisplayBrightness() async {
    loads++;
    final failure = loadError;
    if (failure != null) {
      throw failure;
    }
    return _state;
  }

  @override
  Future<DisplayBrightnessSetting> saveDisplayBrightness(int level) async {
    saves.add(level);
    await saveGate?.future;
    final failure = saveError;
    if (failure != null) {
      saveError = null;
      throw failure;
    }
    percent = level;
    return _state;
  }
}
