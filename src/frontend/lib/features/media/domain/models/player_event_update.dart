import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart';

/// Kind of `PlayerEvent.event` emitted by the backend player stream.
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

/// Maps the protobuf enum onto the presentation-layer event kind.
PlayerEventKind playerEventKindFrom(PlayerEventType raw) {
  return switch (raw) {
    PlayerEventType.PLAYER_SNAPSHOT => PlayerEventKind.snapshot,
    PlayerEventType.PLAYER_POSITION_CHANGED => PlayerEventKind.positionChanged,
    PlayerEventType.PLAYER_PLAYBACK_STARTED => PlayerEventKind.playbackStarted,
    PlayerEventType.PLAYER_RESUMED => PlayerEventKind.resumed,
    PlayerEventType.PLAYER_PAUSED => PlayerEventKind.paused,
    PlayerEventType.PLAYER_STOPPED => PlayerEventKind.stopped,
    PlayerEventType.PLAYER_TRACK_CHANGED => PlayerEventKind.trackChanged,
    PlayerEventType.PLAYER_ERROR => PlayerEventKind.error,
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
