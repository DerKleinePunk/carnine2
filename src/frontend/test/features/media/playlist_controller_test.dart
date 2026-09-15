import 'package:carnine_frontend/features/media/domain/media_backend_exception.dart';
import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/presentation/playlist_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_media_repository.dart';

const _trackA = MediaLibraryTrack(
  id: 1,
  sourceId: 1,
  path: '/music/a.mp3',
  title: 'A',
  artist: 'Artist A',
  duration: Duration(minutes: 3),
  availability: MediaAvailability.available,
);

void main() {
  late FakeMediaRepository repository;
  late PlaylistController controller;

  setUp(() {
    repository = FakeMediaRepository()..library = const [_trackA];
    controller = PlaylistController(repository: repository);
  });

  test('an empty name is rejected without calling the backend', () async {
    final id = await controller.createPlaylist('   ');

    expect(id, isNull);
    expect(controller.createErrorKey, AppTextKey.mediaPlaylistNameRequired);
    expect(repository.playlists, isEmpty);
  });

  test('a successful create stages the add-entries target', () async {
    final id = await controller.createPlaylist('Drive');

    expect(id, isNotNull);
    expect(controller.pendingAddEntriesTarget?.name, 'Drive');
  });

  test('alreadyExists maps to the duplicate-name error message', () async {
    repository.nextError = const MediaBackendException(
      MediaErrorKind.alreadyExists,
      'dup',
    );

    final id = await controller.createPlaylist('Drive');

    expect(id, isNull);
    expect(controller.createErrorKey, AppTextKey.mediaPlaylistExistsError);
  });

  test('openPlaylistById resolves entries against the library cache', () async {
    repository.playlistDetails[1] = const MediaPlaylist(
      id: 1,
      name: 'Drive',
      entries: [
        MediaPlaylistEntry(
          id: 1,
          playlistId: 1,
          mediaId: 1,
          position: 0,
          track: _trackA,
        ),
        // mediaId 99 is not in the cache - the repository would resolve
        // this entry's track to null.
        MediaPlaylistEntry(
          id: 2,
          playlistId: 1,
          mediaId: 99,
          position: 1,
          track: null,
        ),
      ],
    );

    await controller.openPlaylistById(1);

    expect(controller.openPlaylist?.entries[0].track?.title, 'A');
    expect(controller.openPlaylist?.entries[1].track, isNull);
  });

  test(
    'an offline failure on loadPlaylists reports and surfaces offline',
    () async {
      repository.nextError = const MediaBackendException(
        MediaErrorKind.offline,
        'unreachable',
      );
      var reported = false;
      controller = PlaylistController(
        repository: repository,
        onStreamFailure: (_) => reported = true,
      );

      await controller.loadPlaylists();

      expect(reported, isTrue);
    },
  );

  test('fetchPlaylistForPlayback returns the full playlist without touching '
      'openPlaylist/detailState - the Collections overview only has the '
      'entries-free listPlaylists() view and must not navigate to the detail '
      'page just to start playback', () async {
    repository.playlistDetails[1] = const MediaPlaylist(
      id: 1,
      name: 'Drive',
      entries: [
        MediaPlaylistEntry(
          id: 1,
          playlistId: 1,
          mediaId: 1,
          position: 0,
          track: _trackA,
        ),
      ],
    );

    final playlist = await controller.fetchPlaylistForPlayback(1);

    expect(playlist?.entries, hasLength(1));
    expect(controller.openPlaylist, isNull);
  });

  test('startAddingEntries seeds already-added from the playlist\'s current '
      'entries, so a track added in a previous session reads as already '
      'added instead of being offered again', () async {
    const playlist = MediaPlaylist(
      id: 1,
      name: 'Drive',
      entries: [
        MediaPlaylistEntry(
          id: 1,
          playlistId: 1,
          mediaId: 1,
          position: 0,
          track: _trackA,
        ),
      ],
    );

    controller.startAddingEntries(playlist);

    expect(controller.addedMediaIds, contains(1));
  });

  test('addEntry rejects a track already in the playlist without calling the '
      'backend again, and surfaces a hint', () async {
    const playlist = MediaPlaylist(
      id: 1,
      name: 'Drive',
      entries: [
        MediaPlaylistEntry(
          id: 1,
          playlistId: 1,
          mediaId: 1,
          position: 0,
          track: _trackA,
        ),
      ],
    );
    controller.startAddingEntries(playlist);

    await controller.addEntry(playlistId: 1, mediaId: 1);

    expect(repository.commands, isEmpty);
    expect(
      controller.addEntryHintKey,
      AppTextKey.mediaPlaylistTrackAlreadyAdded,
    );
  });

  test('dismissAddEntryHint clears the hint early', () async {
    const playlist = MediaPlaylist(
      id: 1,
      name: 'Drive',
      entries: [
        MediaPlaylistEntry(
          id: 1,
          playlistId: 1,
          mediaId: 1,
          position: 0,
          track: _trackA,
        ),
      ],
    );
    controller.startAddingEntries(playlist);
    await controller.addEntry(playlistId: 1, mediaId: 1);
    expect(controller.addEntryHintKey, isNotNull);

    controller.dismissAddEntryHint();

    expect(controller.addEntryHintKey, isNull);
  });
}
