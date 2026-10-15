/// What the backend keeps about the spoken announcements of the navigation
/// (`NavigationService.GetVoiceSettings`, #110).
class AnnouncementSettings {
  const AnnouncementSettings({
    required this.available,
    required this.enabled,
    required this.volumePercent,
    required this.musicUnderPercent,
    this.voice = '',
  });

  /// A voice is installed and loaded; without one the settings do nothing.
  final bool available;
  final bool enabled;

  /// Loudness of the announcements, 0 to 100.
  final int volumePercent;

  /// The music's level while a sentence plays, 0 to 100. 0 holds the track,
  /// 100 leaves it as loud as it was.
  final int musicUnderPercent;

  /// Name of the installed voice, e.g. `thorsten-medium`.
  final String voice;

  AnnouncementSettings copyWith({
    bool? enabled,
    int? volumePercent,
    int? musicUnderPercent,
  }) {
    return AnnouncementSettings(
      available: available,
      enabled: enabled ?? this.enabled,
      volumePercent: volumePercent ?? this.volumePercent,
      musicUnderPercent: musicUnderPercent ?? this.musicUnderPercent,
      voice: voice,
    );
  }
}

/// Where the options get the settings of the announcements from, and where
/// they save them. The backend keeps them; the frontend stores nothing.
abstract interface class AnnouncementSettingsStore {
  Future<AnnouncementSettings> loadAnnouncementSettings();

  /// Saves only what is given and returns the settings now in effect. Nothing
  /// is saved when a value is above 100.
  Future<AnnouncementSettings> saveAnnouncementSettings({
    bool? enabled,
    int? volumePercent,
    int? musicUnderPercent,
  });

  /// Speaks [text] now, like a turn instruction.
  Future<void> announce(String text);
}
