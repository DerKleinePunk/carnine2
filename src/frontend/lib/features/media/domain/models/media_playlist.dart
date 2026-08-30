import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';

/// A saved playlist entry, with its media resolved against the library cache
/// when available.
///
/// [track] is `null` when [mediaId] is no longer present in the cache - for
/// example a file removed by a rescan. The UI renders that entry as unknown
/// rather than dropping it, since the backend still counts it as a member of
/// the playlist.
class MediaPlaylistEntry {
  const MediaPlaylistEntry({
    required this.id,
    required this.playlistId,
    required this.mediaId,
    required this.position,
    required this.track,
  });

  final int id;
  final int playlistId;
  final int mediaId;
  final int position;
  final MediaLibraryTrack? track;
}

/// A saved playlist and its entries in order.
///
/// `MediaService.ListPlaylists` never returns entries (only `GetPlaylist`
/// does), so a playlist coming from the list RPC always has an empty
/// [entries] list - callers must not treat that as "this playlist is empty".
class MediaPlaylist {
  const MediaPlaylist({
    required this.id,
    required this.name,
    required this.entries,
  });

  final int id;
  final String name;
  final List<MediaPlaylistEntry> entries;
}
