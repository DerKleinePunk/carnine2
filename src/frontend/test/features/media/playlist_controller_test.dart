import 'package:carnine_frontend/features/media/domain/media_backend_exception.dart';
import 'package:carnine_frontend/features/media/domain/models/library_scan_event.dart';
import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/presentation/models/media_view_state.dart';
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

const _trackB = MediaLibraryTrack(
  id: 2,
  sourceId: 1,
  path: '/music/b.mp3',
  title: 'B',
  artist: 'Artist B',
  duration: Duration(minutes: 3),
  availability: MediaAvailability.available,
);

void main() {
  late FakeMediaRepository repository;
  late PlaylistController controller;

  setUp(() {
    repository = FakeMediaRepository()..library = const [_trackA, _trackB];
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

  test('a playlist_created event from another session appends the new '
      'playlist without a restart', () async {
    await controller.start();
    expect(controller.playlists, isEmpty);

    repository.libraryEventsController.add(
      const LibraryScanEvent(
        kind: LibraryScanEventKind.playlistCreated,
        scanId: 0,
        processed: 0,
        imported: 0,
        path: '',
        message: '',
        playlistId: 7,
        playlistName: 'Road Trip',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.playlists, hasLength(1));
    expect(controller.playlists.single.name, 'Road Trip');
  });

  test(
    'a playlist_created event for a playlist this controller already '
    'knows about (its own optimistic create) is not appended twice',
    () async {
      await controller.start();
      final id = await controller.createPlaylist('Drive');
      expect(controller.playlists, hasLength(1));

      repository.libraryEventsController.add(
        LibraryScanEvent(
          kind: LibraryScanEventKind.playlistCreated,
          scanId: 0,
          processed: 0,
          imported: 0,
          path: '',
          message: '',
          playlistId: id!,
          playlistName: 'Drive',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.playlists, hasLength(1));
    },
  );

  LibraryScanEvent createdEvent(MediaPlaylist playlist) => LibraryScanEvent(
    kind: LibraryScanEventKind.playlistCreated,
    scanId: 0,
    processed: 0,
    imported: 0,
    path: '',
    message: '',
    playlistId: playlist.id,
    playlistName: playlist.name,
  );

  test('the very first playlist shows up without a restart (#46)', () async {
    await controller.start();
    expect(controller.listState.status, MediaViewStatus.empty);

    await controller.createPlaylist('Kinder');

    expect(controller.listState.isReady, isTrue);
    expect(controller.playlists.map((playlist) => playlist.name), ['Kinder']);
  });

  test('a playlist_created event arriving before the create reply leaves one '
      'entry at its sorted position (#46)', () async {
    repository.playlists = const [
      MediaPlaylist(id: 1, name: 'Alpha', entries: []),
      MediaPlaylist(id: 2, name: 'Zulu', entries: []),
    ];
    await controller.start();
    repository.beforeCreateReplies = (playlist) async {
      repository.libraryEventsController.add(createdEvent(playlist));
      await Future<void>.delayed(Duration.zero);
    };

    await controller.createPlaylist('Kinder');
    repository.libraryEventsController.add(
      createdEvent(repository.playlists.last),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.playlists.map((playlist) => playlist.name), [
      'Alpha',
      'Kinder',
      'Zulu',
    ]);
  });

  test(
    'a playlist_created event from another session is inserted sorted',
    () async {
      repository.playlists = const [
        MediaPlaylist(id: 1, name: 'Alpha', entries: []),
        MediaPlaylist(id: 2, name: 'Zulu', entries: []),
      ];
      await controller.start();

      repository.libraryEventsController.add(
        createdEvent(const MediaPlaylist(id: 3, name: 'Middle', entries: [])),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.playlists.map((playlist) => playlist.name), [
        'Alpha',
        'Middle',
        'Zulu',
      ]);
    },
  );

  test('a playlist_entry_added event for the open playlist refreshes its '
      'entries without the caller re-opening it', () async {
    repository.playlistDetails[1] = const MediaPlaylist(
      id: 1,
      name: 'Drive',
      entries: [],
    );
    await controller.start();
    await controller.openPlaylistById(1);
    expect(controller.openPlaylist?.entries, isEmpty);

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
    repository.libraryEventsController.add(
      const LibraryScanEvent(
        kind: LibraryScanEventKind.playlistEntryAdded,
        scanId: 0,
        processed: 0,
        imported: 0,
        path: '',
        message: '',
        playlistId: 1,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.openPlaylist?.entries, hasLength(1));
  });

  test('a playlist_entry_added event for a playlist that is not open is '
      'ignored', () async {
    await controller.start();

    repository.libraryEventsController.add(
      const LibraryScanEvent(
        kind: LibraryScanEventKind.playlistEntryAdded,
        scanId: 0,
        processed: 0,
        imported: 0,
        path: '',
        message: '',
        playlistId: 42,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.openPlaylist, isNull);
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

  test('createPlaylist inserts the new playlist at its sorted position, not '
      'appended at the end where it could scroll out of view', () async {
    repository.playlists = const [
      MediaPlaylist(id: 1, name: 'Alpha', entries: []),
      MediaPlaylist(id: 2, name: 'Zulu', entries: []),
    ];
    await controller.loadPlaylists();

    await controller.createPlaylist('Middle');

    expect(controller.playlists.map((playlist) => playlist.name), [
      'Alpha',
      'Middle',
      'Zulu',
    ]);
  });

  test('addEntry reflects the new entry in the currently open playlist '
      'immediately, instead of only after fully re-opening it', () async {
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
    await controller.openPlaylistById(1);
    expect(controller.openPlaylist?.entries, hasLength(1));

    await controller.addEntry(playlistId: 1, mediaId: 2);

    expect(controller.openPlaylist?.entries, hasLength(2));
    expect(controller.openPlaylist?.entries.last.mediaId, 2);
  });

  test(
    'addEntry does not touch openPlaylist when a different playlist is open',
    () async {
      repository.playlistDetails[1] = const MediaPlaylist(
        id: 1,
        name: 'Drive',
        entries: [],
      );
      await controller.openPlaylistById(1);

      // Adding to a *different* playlist (e.g. via the add-entries flow
      // reached from the Collections overview for another playlist) must
      // not bleed into the one currently open on the detail page.
      await controller.addEntry(playlistId: 2, mediaId: 1);

      expect(controller.openPlaylist?.entries, isEmpty);
    },
  );

  group('editing playlists (#89)', () {
    const entryA = MediaPlaylistEntry(
      id: 11,
      playlistId: 1,
      mediaId: 1,
      position: 0,
      track: _trackA,
    );
    const entryB = MediaPlaylistEntry(
      id: 12,
      playlistId: 1,
      mediaId: 2,
      position: 1,
      track: _trackB,
    );

    const drive = MediaPlaylist(
      id: 1,
      name: 'Drive',
      entries: [entryA, entryB],
    );

    LibraryScanEvent event(
      LibraryScanEventKind kind, {
      int playlistId = 0,
      String name = '',
    }) => LibraryScanEvent(
      kind: kind,
      scanId: 0,
      processed: 0,
      imported: 0,
      path: '',
      message: '',
      playlistId: playlistId,
      playlistName: name,
    );

    List<String> names() =>
        controller.playlists.map((playlist) => playlist.name).toList();

    setUp(() async {
      repository.playlists = const [
        MediaPlaylist(id: 1, name: 'Drive', entries: []),
        MediaPlaylist(id: 2, name: 'Zulu', entries: []),
      ];
      repository.playlistDetails[1] = drive;
      await controller.start();
    });

    tearDown(() {
      controller.dispose();
    });

    test('renaming trims the name and puts the playlist at its sorted '
        'place', () async {
      controller.startRenaming(controller.playlists.first);

      final done = await controller.renamePlaylist('  Zzz  ');

      expect(done, isTrue);
      expect(repository.commands, contains('renamePlaylist:1:Zzz'));
      expect(names(), ['Zulu', 'Zzz']);
      expect(controller.renameTarget, isNull);
    });

    test('renaming to the same name closes the page without a call', () async {
      controller.startRenaming(controller.playlists.first);

      final done = await controller.renamePlaylist('Drive');

      expect(done, isTrue);
      expect(controller.renameTarget, isNull);
      expect(
        repository.commands.where((c) => c.startsWith('renamePlaylist')),
        isEmpty,
      );
    });

    test('an empty new name is rejected and the page stays', () async {
      controller.startRenaming(controller.playlists.first);

      final done = await controller.renamePlaylist('   ');

      expect(done, isFalse);
      expect(controller.renameErrorKey, AppTextKey.mediaPlaylistNameRequired);
      expect(controller.renameTarget, isNotNull);
    });

    test(
      'a name another playlist has shows the duplicate-name error',
      () async {
        controller.startRenaming(controller.playlists.first);
        repository.nextError = const MediaBackendException(
          MediaErrorKind.alreadyExists,
          'dup',
        );

        final done = await controller.renamePlaylist('Zulu');

        expect(done, isFalse);
        expect(controller.renameErrorKey, AppTextKey.mediaPlaylistExistsError);
        expect(controller.renameTarget?.id, 1);
        expect(controller.isRenaming, isFalse);
      },
    );

    test('renaming the open playlist renames its detail page too', () async {
      await controller.openPlaylistById(1);
      controller.startRenaming(drive);

      await controller.renamePlaylist('Road');

      expect(controller.openPlaylist?.name, 'Road');
      expect(controller.openPlaylist?.entries, hasLength(2));
    });

    test(
      'deleting removes the playlist and closes it if it was open',
      () async {
        await controller.openPlaylistById(1);

        final gone = await controller.deletePlaylist(1);

        expect(gone, isTrue);
        expect(repository.commands, contains('deletePlaylist:1'));
        expect(names(), ['Zulu']);
        expect(controller.openPlaylist, isNull);
      },
    );

    test('deleting the last playlist shows the empty list', () async {
      await controller.deletePlaylist(1);
      await controller.deletePlaylist(2);

      expect(controller.playlists, isEmpty);
      expect(controller.listState.status, MediaViewStatus.empty);
      expect(controller.listState.messageKey, AppTextKey.mediaPlaylistsEmpty);
    });

    test('a failed delete keeps the playlist and says so', () async {
      repository.nextError = const MediaBackendException(
        MediaErrorKind.unknown,
        'boom',
      );

      final gone = await controller.deletePlaylist(1);

      expect(gone, isFalse);
      expect(names(), ['Drive', 'Zulu']);
      expect(controller.actionErrorKey, AppTextKey.mediaCommandFailed);

      controller.dismissActionError();
      expect(controller.actionErrorKey, isNull);
    });

    test(
      'deleting a playlist the backend no longer knows counts as done',
      () async {
        repository.nextError = const MediaBackendException(
          MediaErrorKind.notFound,
          'gone',
        );

        final gone = await controller.deletePlaylist(1);

        expect(gone, isTrue);
        expect(names(), ['Zulu']);
        expect(controller.actionErrorKey, isNull);
      },
    );

    test(
      'removing an entry shows the playlist as the backend returns it',
      () async {
        await controller.openPlaylistById(1);

        await controller.removeEntry(entryA);

        expect(repository.commands, contains('removePlaylistEntry:11'));
        final entries = controller.openPlaylist?.entries ?? const [];
        expect(entries, hasLength(1));
        expect(entries.first.mediaId, 2);
        expect(entries.first.position, 0);
        expect(controller.pendingRemoveEntryIds, isEmpty);
      },
    );

    test('removing the last entry leaves the empty-playlist message', () async {
      await controller.openPlaylistById(1);
      await controller.removeEntry(entryA);
      await controller.removeEntry(entryB);

      expect(controller.detailState.status, MediaViewStatus.empty);
      expect(
        controller.detailState.messageKey,
        AppTextKey.mediaPlaylistDetailEmpty,
      );
    });

    test('a failed removal keeps the entry and says so', () async {
      await controller.openPlaylistById(1);
      repository.nextError = const MediaBackendException(
        MediaErrorKind.unknown,
        'boom',
      );

      await controller.removeEntry(entryA);

      expect(controller.openPlaylist?.entries, hasLength(2));
      expect(controller.actionErrorKey, AppTextKey.mediaCommandFailed);
      expect(controller.pendingRemoveEntryIds, isEmpty);
    });

    test(
      'a rename from elsewhere reaches the list and the open page',
      () async {
        await controller.openPlaylistById(1);

        repository.libraryEventsController.add(
          event(
            LibraryScanEventKind.playlistRenamed,
            playlistId: 1,
            name: 'Zzz',
          ),
        );
        await pumpEventQueue();

        expect(names(), ['Zulu', 'Zzz']);
        expect(controller.openPlaylist?.name, 'Zzz');
      },
    );

    test('a delete from elsewhere closes the page that was open', () async {
      await controller.openPlaylistById(1);
      controller.startRenaming(drive);

      repository.libraryEventsController.add(
        event(LibraryScanEventKind.playlistDeleted, playlistId: 1),
      );
      await pumpEventQueue();

      expect(names(), ['Zulu']);
      expect(controller.openPlaylist, isNull);
      expect(controller.renameTarget, isNull);
    });

    test('an entry removed elsewhere refreshes the open page without '
        'blanking it', () async {
      await controller.openPlaylistById(1);
      var wasBlank = false;
      controller.addListener(() {
        wasBlank = wasBlank || controller.openPlaylist == null;
      });
      repository.playlistDetails[1] = const MediaPlaylist(
        id: 1,
        name: 'Drive',
        entries: [entryB],
      );

      repository.libraryEventsController.add(
        event(LibraryScanEventKind.playlistEntryRemoved, playlistId: 1),
      );
      await pumpEventQueue();

      expect(controller.openPlaylist?.entries, hasLength(1));
      expect(wasBlank, isFalse);
    });
  });
}
