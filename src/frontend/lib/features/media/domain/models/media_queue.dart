import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';

/// How the current queue was built.
///
/// There is no queue RPC in the backend contract, so the queue is derived
/// client-side from the command that created it, mirroring exactly what
/// `MediaPlayer` does server-side for `Play` and `PlayPlaylist`.
enum MediaQueueOrigin {
  none,
  singleTrack,
  playlist,
}

/// The frontend's local reconstruction of the backend's temporary queue.
class MediaQueue {
  const MediaQueue({
    required this.origin,
    required this.playlistId,
    required this.playlistName,
    required this.tracks,
  });

  const MediaQueue.empty()
      : origin = MediaQueueOrigin.none,
        playlistId = null,
        playlistName = null,
        tracks = const <MediaLibraryTrack>[];

  final MediaQueueOrigin origin;
  final int? playlistId;
  final String? playlistName;
  final List<MediaLibraryTrack> tracks;

  bool get isEmpty => tracks.isEmpty;

  /// Index of the track whose path matches [mediaPath], or `null` when the
  /// path is not part of this queue (or the queue is empty).
  int? indexOfPath(String mediaPath) {
    if (mediaPath.isEmpty) {
      return null;
    }

    final index = tracks.indexWhere((track) => track.path == mediaPath);
    return index == -1 ? null : index;
  }
}
