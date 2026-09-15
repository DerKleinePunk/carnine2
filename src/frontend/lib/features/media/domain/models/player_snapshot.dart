/// Playback state reported by the backend player.
enum PlaybackStatus { stopped, playing, paused }

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

/// Repeat behaviour for the active queue, mirrored from the backend's
/// `RepeatMode` enum (`docs/20-media-backend-plan.md`: aus/Queue/Titel).
enum MediaRepeatMode { off, queue, track }

/// Immutable view of the backend player at one point in time.
///
/// The contract's `duration_ms` is deliberately dropped: the backend still
/// reports zero, so track length only ever comes from the media library.
class PlayerSnapshot {
  const PlayerSnapshot({
    required this.status,
    required this.mediaPath,
    required this.position,
    this.playlistId,
    this.repeatMode = MediaRepeatMode.off,
    this.shuffleEnabled = false,
  });

  const PlayerSnapshot.stopped()
    : status = PlaybackStatus.stopped,
      mediaPath = '',
      position = Duration.zero,
      playlistId = null,
      repeatMode = MediaRepeatMode.off,
      shuffleEnabled = false;

  final PlaybackStatus status;
  final String mediaPath;
  final Duration position;
  final int? playlistId;
  final MediaRepeatMode repeatMode;
  final bool shuffleEnabled;

  bool get hasMedia => mediaPath.isNotEmpty;
}
