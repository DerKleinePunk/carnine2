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
    repository.nextError =
        const MediaBackendException(MediaErrorKind.alreadyExists, 'dup');

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
            id: 1, playlistId: 1, mediaId: 1, position: 0, track: _trackA),
        // mediaId 99 is not in the cache - the repository would resolve
        // this entry's track to null.
        MediaPlaylistEntry(
            id: 2, playlistId: 1, mediaId: 99, position: 1, track: null),
      ],
    );

    await controller.openPlaylistById(1);

    expect(controller.openPlaylist?.entries[0].track?.title, 'A');
    expect(controller.openPlaylist?.entries[1].track, isNull);
  });

  test('an offline failure on loadPlaylists reports and surfaces offline',
      () async {
    repository.nextError =
        const MediaBackendException(MediaErrorKind.offline, 'unreachable');
    var reported = false;
    controller = PlaylistController(
      repository: repository,
      onStreamFailure: (_) => reported = true,
    );

    await controller.loadPlaylists();

    expect(reported, isTrue);
  });
}
