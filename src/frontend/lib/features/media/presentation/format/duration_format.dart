/// Formats [duration] as `mm:ss`. Use for values that are meaningfully zero,
/// such as the current playback position.
String formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Formats a track's total [duration] as `mm:ss`, or `--:--` when it is
/// unknown (the backend's `PlayerState.duration_ms` is always zero, so track
/// length only ever comes from the media library cache - a zero here means
/// "we don't know", not "zero seconds long").
String formatTrackDuration(Duration? duration) {
  if (duration == null || duration <= Duration.zero) {
    return '--:--';
  }

  return formatDuration(duration);
}
