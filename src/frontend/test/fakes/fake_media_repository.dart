import 'dart:async';

import 'package:carnine_frontend/features/media/domain/media_backend_exception.dart';
import 'package:carnine_frontend/features/media/domain/media_repository.dart';
import 'package:carnine_frontend/features/media/domain/models/library_scan_event.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/domain/models/player_event_update.dart';
import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';

/// Hand-written [MediaRepository] fake for widget/controller tests.
///
/// [commands] records every command call, in order, as a short string (e.g.
/// `'stop'`, `'play:/music/a.mp3'`, `'playPlaylist:3'`) so tests can assert
/// on call *order* - the thing that actually matters for the backend
/// quirks this repository's real implementation works around.
class FakeMediaRepository implements MediaRepository {
  List<MediaLibraryTrack> library = const [];
  List<MediaPlaylist> playlists = const [];
  final Map<int, MediaPlaylist> playlistDetails = {};

  final List<String> commands = [];

  /// When set, the next repository call throws this instead of succeeding.
  /// Cleared automatically after firing once.
  MediaBackendException? nextError;

  final StreamController<PlayerEventUpdate> playerEventsController =
      StreamController<PlayerEventUpdate>.broadcast();
  final StreamController<LibraryScanEvent> libraryEventsController =
      StreamController<LibraryScanEvent>.broadcast();
  final StreamController<LibraryScanEvent> rescanController =
      StreamController<LibraryScanEvent>.broadcast();

  int reconnectCallCount = 0;
  int disposeCallCount = 0;

  Future<void> _maybeThrow() async {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  @override
  List<MediaLibraryTrack> get cachedLibrary => List.unmodifiable(library);

  @override
  MediaLibraryTrack? trackForPath(String path) {
    for (final track in library) {
      if (track.path == path) {
        return track;
      }
    }
    return null;
  }

  @override
  MediaLibraryTrack? trackForId(int mediaId) {
    for (final track in library) {
      if (track.id == mediaId) {
        return track;
      }
    }
    return null;
  }

  bool _libraryLoadedOnce = false;

  @override
  Future<List<MediaLibraryTrack>> loadLibrary() async {
    await _maybeThrow();
    _libraryLoadedOnce = true;
    return cachedLibrary;
  }

  @override
  Future<List<MediaLibraryTrack>> search(String query) async {
    await _maybeThrow();
    if (query.isEmpty) {
      return cachedLibrary;
    }
    final lower = query.toLowerCase();
    return library
        .where((track) =>
            track.title.toLowerCase().contains(lower) ||
            track.artist.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Future<void> ensureLibraryLoaded() async {
    if (!_libraryLoadedOnce) {
      await loadLibrary();
    }
  }

  @override
  Future<PlayerSnapshot> playerState() async {
    await _maybeThrow();
    return const PlayerSnapshot.stopped();
  }

  @override
  Future<void> startTrack(String mediaPath) async {
    commands.add('stop');
    await _maybeThrow();
    commands.add('play:$mediaPath');
    await _maybeThrow();
  }

  @override
  Future<void> resume() async {
    commands.add('play:');
    await _maybeThrow();
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
    await _maybeThrow();
  }

  @override
  Future<void> stop() async {
    commands.add('stop');
    await _maybeThrow();
  }

  @override
  Future<void> next() async {
    commands.add('next');
    await _maybeThrow();
  }

  @override
  Future<void> previous() async {
    commands.add('previous');
    await _maybeThrow();
  }

  @override
  Future<void> restartCurrentTrack() async {
    commands.add('restartCurrentTrack');
    await _maybeThrow();
  }

  @override
  Future<void> startPlaylist(int playlistId) async {
    commands.add('playPlaylist:$playlistId');
    await _maybeThrow();
    commands.add('play:');
    await _maybeThrow();
  }

  @override
  Stream<PlayerEventUpdate> playerEvents() => playerEventsController.stream;

  @override
  Stream<LibraryScanEvent> libraryEvents() => libraryEventsController.stream;

  @override
  Stream<LibraryScanEvent> rescan() => rescanController.stream;

  @override
  Future<List<MediaPlaylist>> listPlaylists() async {
    await _maybeThrow();
    return List.unmodifiable(playlists);
  }

  @override
  Future<MediaPlaylist> getPlaylist(int playlistId) async {
    await _maybeThrow();
    final playlist = playlistDetails[playlistId];
    if (playlist == null) {
      throw const MediaBackendException(MediaErrorKind.notFound, 'not found');
    }
    return playlist;
  }

  @override
  Future<MediaPlaylist> createPlaylist(String name) async {
    await _maybeThrow();
    final playlist =
        MediaPlaylist(id: playlists.length + 1, name: name, entries: const []);
    playlists = [...playlists, playlist];
    return playlist;
  }

  @override
  Future<MediaPlaylistEntry> addPlaylistEntry({
    required int playlistId,
    required int mediaId,
  }) async {
    await _maybeThrow();
    return MediaPlaylistEntry(
      id: 1,
      playlistId: playlistId,
      mediaId: mediaId,
      position: 0,
      track: trackForId(mediaId),
    );
  }

  @override
  Future<void> reconnect() async {
    reconnectCallCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    await playerEventsController.close();
    await libraryEventsController.close();
    await rescanController.close();
  }
}
