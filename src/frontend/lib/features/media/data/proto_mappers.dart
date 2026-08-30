import 'package:carnine_frontend/features/media/domain/models/library_scan_event.dart';
import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/player_event_update.dart';
import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart';
import 'package:fixnum/fixnum.dart';

/// Converts a protobuf `uint64`/`int64` id field to a Dart [int].
///
/// Safe here: ids are SQLite row ids and stay far below 2^53, the point
/// where [Int64.toInt] would start losing precision on the web runtime.
int idFrom(Int64 value) => value.toInt();

/// Converts a protobuf millisecond duration field to a [Duration], clamping
/// negative values to zero (an unparsed file can report `-1`).
Duration durationFrom(Int64 milliseconds) {
  final ms = milliseconds.toInt();
  return Duration(milliseconds: ms < 0 ? 0 : ms);
}

MediaLibraryTrack trackFromProto(MediaItem item) {
  return MediaLibraryTrack(
    id: idFrom(item.id),
    sourceId: idFrom(item.sourceId),
    path: item.path,
    title: item.title,
    artist: item.artist,
    duration: durationFrom(item.durationMs),
    availability: mediaAvailabilityFrom(item.status),
  );
}

PlayerSnapshot snapshotFromProto(PlayerState state) {
  return PlayerSnapshot(
    status: playbackStatusFrom(state.status),
    mediaPath: state.mediaPath,
    position: durationFrom(state.positionMs),
  );
}

PlayerEventUpdate playerEventFromProto(PlayerEvent event) {
  return PlayerEventUpdate(
    kind: playerEventKindFrom(event.event),
    state: event.hasState() ? snapshotFromProto(event.state) : null,
    message: event.message,
  );
}

LibraryScanEvent scanEventFromProto(LibraryEvent event) {
  return LibraryScanEvent(
    kind: libraryScanEventKindFrom(event.event),
    scanId: idFrom(event.scanId),
    processed: idFrom(event.processed),
    imported: idFrom(event.imported),
    path: event.path,
    message: event.message,
  );
}
