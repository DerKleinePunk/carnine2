import 'dart:async';

import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/domain/models/player_event_update.dart';
import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_media_repository.dart';

const _track = MediaLibraryTrack(
  id: 1,
  sourceId: 1,
  path: '/music/celluloid-heroes.mp3',
  title: 'Celluloid Heroes',
  artist: 'The Kinks',
  duration: Duration(minutes: 5),
  availability: MediaAvailability.available,
);

const _nextTrack = MediaLibraryTrack(
  id: 2,
  sourceId: 1,
  path: '/music/lola.mp3',
  title: 'Lola',
  artist: 'The Kinks',
  duration: Duration(minutes: 4),
  availability: MediaAvailability.available,
);

const _playlist = MediaPlaylist(
  id: 4,
  name: 'Kinks',
  entries: [
    MediaPlaylistEntry(
      id: 1,
      playlistId: 4,
      mediaId: 1,
      position: 0,
      track: _track,
    ),
    MediaPlaylistEntry(
      id: 2,
      playlistId: 4,
      mediaId: 2,
      position: 1,
      track: _nextTrack,
    ),
  ],
);

/// Knows a track only once the library has been loaded, like the gRPC
/// repository's path index, and holds that load until [releaseLibrary].
class _SlowLibraryRepository extends FakeMediaRepository {
  final Completer<void> _libraryGate = Completer<void>();
  bool _loaded = false;

  void releaseLibrary() => _libraryGate.complete();

  @override
  MediaLibraryTrack? trackForPath(String path) =>
      _loaded ? super.trackForPath(path) : null;

  @override
  MediaLibraryTrack? trackForId(int mediaId) =>
      _loaded ? super.trackForId(mediaId) : null;

  /// Like the gRPC repository, the entries name their tracks from the
  /// library cache.
  @override
  Future<MediaPlaylist> getPlaylist(int playlistId) async {
    final playlist = await super.getPlaylist(playlistId);
    return MediaPlaylist(
      id: playlist.id,
      name: playlist.name,
      entries: [
        for (final entry in playlist.entries)
          MediaPlaylistEntry(
            id: entry.id,
            playlistId: entry.playlistId,
            mediaId: entry.mediaId,
            position: entry.position,
            track: trackForId(entry.mediaId),
          ),
      ],
    );
  }

  @override
  Future<void> ensureLibraryLoaded() async {
    await _libraryGate.future;
    _loaded = true;
    await super.ensureLibraryLoaded();
  }
}

PlayerEventUpdate _pausedSnapshot({int? playlistId}) => PlayerEventUpdate(
  kind: PlayerEventKind.snapshot,
  state: PlayerSnapshot(
    status: PlaybackStatus.paused,
    mediaPath: _track.path,
    position: const Duration(seconds: 70),
    playlistId: playlistId,
  ),
  message: 'current player state',
);

void main() {
  late _SlowLibraryRepository repository;
  late MediaController controller;

  setUp(() {
    repository = _SlowLibraryRepository()
      ..library = const [_track, _nextTrack]
      ..playlistDetails[_playlist.id] = _playlist;
    controller = MediaController(repository: repository);
  });

  tearDown(() => controller.dispose());

  // #81: the player stream opens before the library has loaded, and a
  // paused single track gets no further event that would name it later.
  test('a paused single track from before the library loaded is named once it '
      'has', () async {
    final started = controller.start();
    await Future<void>.delayed(Duration.zero);

    repository.playerEventsController.add(_pausedSnapshot());
    await Future<void>.delayed(Duration.zero);
    expect(controller.player.currentTrack, isNull);

    repository.releaseLibrary();
    await started;
    await Future<void>.delayed(Duration.zero);

    expect(controller.player.currentTrack?.title, 'Celluloid Heroes');
    expect(controller.player.status, PlaybackStatus.paused);
    expect(controller.player.position, const Duration(seconds: 70));
  });

  test('a paused playlist track from before the library loaded gets its '
      'queue once the library has', () async {
    final started = controller.start();
    await Future<void>.delayed(Duration.zero);

    repository.playerEventsController.add(
      _pausedSnapshot(playlistId: _playlist.id),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.player.currentTrack, isNull);
    expect(controller.player.queue.tracks, isEmpty);

    repository.releaseLibrary();
    await started;
    await Future<void>.delayed(Duration.zero);

    expect(controller.player.currentTrack?.title, 'Celluloid Heroes');
    expect(controller.player.queue.playlistId, _playlist.id);
    expect(controller.player.queue.tracks, [_track, _nextTrack]);
    expect(controller.player.activeQueueIndex, 0);
  });
}
