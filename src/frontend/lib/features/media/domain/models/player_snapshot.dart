/// Playback state reported by the backend player.
enum PlaybackStatus {
  stopped,
  playing,
  paused,
}

/// Maps the backend's `PlayerState.status` string onto [PlaybackStatus].
///
/// Anything unexpected is treated as [PlaybackStatus.stopped] - the safest
/// reading, because it stops the local position ticker.
PlaybackStatus playbackStatusFrom(String raw) {
  return switch (raw.trim().toLowerCase()) {
    'playing' => PlaybackStatus.playing,
    'paused' => PlaybackStatus.paused,
    _ => PlaybackStatus.stopped,
  };
}

/// Immutable view of the backend player at one point in time.
///
/// The contract's `duration_ms` is deliberately dropped: the backend hardcodes
/// it to zero, so track length only ever comes from the media library.
class PlayerSnapshot {
  const PlayerSnapshot({
    required this.status,
    required this.mediaPath,
    required this.position,
  });

  const PlayerSnapshot.stopped()
      : status = PlaybackStatus.stopped,
        mediaPath = '',
        position = Duration.zero;

  final PlaybackStatus status;
  final String mediaPath;
  final Duration position;

  bool get hasMedia => mediaPath.isNotEmpty;
}
