import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';

/// Kind of `PlayerEvent.event` string emitted by the backend player stream.
///
/// [unknown] keeps the mapping forward-compatible: a future backend event
/// name is logged and ignored instead of crashing the UI.
enum PlayerEventKind {
  snapshot,
  positionChanged,
  playbackStarted,
  resumed,
  paused,
  stopped,
  trackChanged,
  error,
  unknown,
}

/// Maps the backend's `PlayerEvent.event` string onto [PlayerEventKind].
PlayerEventKind playerEventKindFrom(String raw) {
  return switch (raw.trim()) {
    'snapshot' => PlayerEventKind.snapshot,
    'position_changed' => PlayerEventKind.positionChanged,
    'playback_started' => PlayerEventKind.playbackStarted,
    'resumed' => PlayerEventKind.resumed,
    'paused' => PlayerEventKind.paused,
    'stopped' => PlayerEventKind.stopped,
    'track_changed' => PlayerEventKind.trackChanged,
    'error' => PlayerEventKind.error,
    _ => PlayerEventKind.unknown,
  };
}

/// One update from `MediaService.StreamPlayerEvents`.
class PlayerEventUpdate {
  const PlayerEventUpdate({
    required this.kind,
    required this.state,
    required this.message,
  });

  final PlayerEventKind kind;
  final PlayerSnapshot? state;
  final String message;
}
