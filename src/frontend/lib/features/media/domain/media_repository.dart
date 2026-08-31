import 'package:carnine_frontend/features/media/domain/models/library_scan_event.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/domain/models/player_event_update.dart';
import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';

/// Contract controllers depend on for all media backend access.
///
/// No protobuf type appears in this interface - implementations translate to
/// and from the domain models so the presentation layer never touches gRPC.
/// All methods throw [MediaBackendException] on failure; they never rethrow
/// the underlying transport error.
abstract class MediaRepository {
  /// Loads the entire library via `SearchMedia("")` and replaces the cache.
  Future<List<MediaLibraryTrack>> loadLibrary();

  /// Searches the library and merges results into the cache.
  Future<List<MediaLibraryTrack>> search(String query);

  /// Loads the library if it has never been loaded yet.
  Future<void> ensureLibraryLoaded();

  /// Looks up a cached track by its backend media path, or `null`.
  MediaLibraryTrack? trackForPath(String path);

  /// Looks up a cached track by its backend media id, or `null`.
  MediaLibraryTrack? trackForId(int mediaId);

  /// The most recently loaded/searched library, unmodifiable.
  List<MediaLibraryTrack> get cachedLibrary;

  Future<PlayerSnapshot> playerState();

  /// Starts [mediaPath] as a new single-track queue.
  ///
  /// The backend's `Play` only resumes when something is already loaded, so
  /// this issues `Stop` first to guarantee the path is actually honoured.
  Future<void> startTrack(String mediaPath);

  /// Resumes the current queue (`Play` with an empty path).
  Future<void> resume();

  Future<void> pause();
  Future<void> stop();
  Future<void> next();
  Future<void> previous();
  Future<void> restartCurrentTrack();
  Future<void> playQueueEntry(int index);

  /// Loads [playlistId] into the queue and starts playback.
  ///
  /// The backend's `PlayPlaylist` leaves playback paused and emits no event
  /// under the shipped `restore_paused` resume mode, so this follows up with
  /// `Play("")` to actually start audio and publish a `playback_started`
  /// event the UI can observe.
  Future<void> startPlaylist(int playlistId);

  /// The live player event stream. Emits an initial `snapshot` event.
  Stream<PlayerEventUpdate> playerEvents();

  /// The long-lived library event stream (manual and automatic rescans).
  Stream<LibraryScanEvent> libraryEvents();

  /// Triggers a full rescan and streams its progress.
  Stream<LibraryScanEvent> rescan();

  /// Lists saved playlists. Entries are always empty on this call - use
  /// [getPlaylist] to load a playlist's entries.
  Future<List<MediaPlaylist>> listPlaylists();

  /// Loads one playlist with its entries resolved against the library cache.
  Future<MediaPlaylist> getPlaylist(int playlistId);

  Future<MediaPlaylist> createPlaylist(String name);

  Future<MediaPlaylistEntry> addPlaylistEntry({
    required int playlistId,
    required int mediaId,
  });

  /// Tears down and rebuilds the underlying transport connection. Used by
  /// the connection-loss reconnect loop; safe to call repeatedly.
  Future<void> reconnect();

  /// Releases the underlying channel. Call once when the media section is
  /// left for good.
  Future<void> dispose();
}
