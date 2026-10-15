import 'dart:async';

import 'package:carnine_frontend/features/settings/data/announcement_settings_store.dart';

/// Hand-written [AnnouncementSettingsStore] for tests: keeps the settings in
/// memory like the backend does. [saves] records every save, e.g.
/// `enabled=false` or `volume=80`; [spoken] every announced sentence.
class FakeAnnouncementSettingsStore implements AnnouncementSettingsStore {
  FakeAnnouncementSettingsStore({
    this.settings = const AnnouncementSettings(
      available: true,
      enabled: true,
      volumePercent: 100,
      musicUnderPercent: 30,
      voice: 'thorsten-medium',
    ),
  });

  AnnouncementSettings settings;

  /// Thrown by loading, to play a backend that is away.
  Object? loadError;

  /// Thrown by the next save, once.
  Object? saveError;

  /// Thrown by the next announcement, once.
  Object? announceError;

  /// Holds a save until completed.
  Completer<void>? saveGate;

  /// Holds an announcement until completed.
  Completer<void>? announceGate;

  int loads = 0;
  final List<String> saves = [];
  final List<String> spoken = [];

  @override
  Future<AnnouncementSettings> loadAnnouncementSettings() async {
    loads++;
    final failure = loadError;
    if (failure != null) {
      throw failure;
    }
    return settings;
  }

  @override
  Future<AnnouncementSettings> saveAnnouncementSettings({
    bool? enabled,
    int? volumePercent,
    int? musicUnderPercent,
  }) async {
    saves.add(
      [
        if (enabled != null) 'enabled=$enabled',
        if (volumePercent != null) 'volume=$volumePercent',
        if (musicUnderPercent != null) 'musicUnder=$musicUnderPercent',
      ].join(','),
    );
    await saveGate?.future;
    final failure = saveError;
    if (failure != null) {
      saveError = null;
      throw failure;
    }
    settings = settings.copyWith(
      enabled: enabled,
      volumePercent: volumePercent,
      musicUnderPercent: musicUnderPercent,
    );
    return settings;
  }

  @override
  Future<void> announce(String text) async {
    spoken.add(text);
    await announceGate?.future;
    final failure = announceError;
    if (failure != null) {
      announceError = null;
      throw failure;
    }
  }
}
