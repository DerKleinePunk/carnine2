/// Availability of a media file as reported by the backend.
///
/// The backend stores this as a raw string constrained to `AVAILABLE`,
/// `OFFLINE` and `MISSING`. Unknown values map to [unknown] so a future
/// backend status degrades gracefully instead of crashing the UI.
enum MediaAvailability {
  available,
  offline,
  missing,
  unknown;

  /// Whether the file can be handed to the player right now.
  bool get isPlayable => this == MediaAvailability.available;
}

/// Maps the backend's `MediaItem.status` string onto [MediaAvailability].
MediaAvailability mediaAvailabilityFrom(String raw) {
  return switch (raw.trim().toUpperCase()) {
    'AVAILABLE' => MediaAvailability.available,
    'OFFLINE' => MediaAvailability.offline,
    'MISSING' => MediaAvailability.missing,
    _ => MediaAvailability.unknown,
  };
}
