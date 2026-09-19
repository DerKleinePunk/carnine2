import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/features/media/domain/models/library_scan_event.dart';
import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/domain/models/player_event_update.dart';
import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';
import 'dart:ui' as ui;

import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_media_repository.dart';
import '../../fakes/media_test_harness.dart';

const _trackA = MediaLibraryTrack(
  id: 1,
  sourceId: 1,
  path: '/music/a.mp3',
  title: 'Neon Dreams',
  artist: 'Cyberpunk Orchestra',
  duration: Duration(minutes: 4, seconds: 56),
  availability: MediaAvailability.available,
);

const _trackMissing = MediaLibraryTrack(
  id: 2,
  sourceId: 1,
  path: '/music/gone.mp3',
  title: 'Ghost Track',
  artist: 'Nobody',
  duration: Duration(minutes: 2),
  availability: MediaAvailability.missing,
);

void main() {
  late FakeMediaRepository repository;
  late MediaController controller;

  setUp(() {
    repository = FakeMediaRepository()
      ..library = const [_trackA, _trackMissing];
    controller = MediaController(repository: repository);
  });

  tearDown(() {
    controller.dispose();
  });

  testWidgets('shows the current track once the player emits a snapshot', (
    tester,
  ) async {
    setUpMediaView(tester);
    await tester.pumpWidget(mediaHarness(controller));
    await tester.pump();

    repository.playerEventsController.add(
      PlayerEventUpdate(
        kind: PlayerEventKind.snapshot,
        state: const PlayerSnapshot(
          status: PlaybackStatus.paused,
          mediaPath: '/music/a.mp3',
          position: Duration(seconds: 5),
        ),
        message: 'current player state',
      ),
    );
    await tester.pump();

    expect(find.text('NEON DREAMS'), findsWidgets);
    expect(find.byIcon(Icons.play_arrow), findsWidgets);
  });

  testWidgets('play/pause taps issue the expected backend commands', (
    tester,
  ) async {
    setUpMediaView(tester);
    await tester.pumpWidget(mediaHarness(controller));
    await tester.pump();

    repository.playerEventsController.add(
      PlayerEventUpdate(
        kind: PlayerEventKind.snapshot,
        state: const PlayerSnapshot(
          status: PlaybackStatus.playing,
          mediaPath: '/music/a.mp3',
          position: Duration.zero,
        ),
        message: 'snapshot',
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.pause), findsOneWidget);
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    expect(repository.commands, ['pause']);

    // Settle playback so no periodic ticker is left running past teardown.
    repository.playerEventsController.add(
      PlayerEventUpdate(
        kind: PlayerEventKind.paused,
        state: const PlayerSnapshot(
          status: PlaybackStatus.paused,
          mediaPath: '/music/a.mp3',
          position: Duration.zero,
        ),
        message: 'playback paused',
      ),
    );
    await tester.pump();
  });

  testWidgets('tapping shuffle toggles it and calls SetShuffleMode', (
    tester,
  ) async {
    setUpMediaView(tester);
    await tester.pumpWidget(mediaHarness(controller));
    await tester.pump();

    final shuffleSemantics = tester.getSemantics(find.byIcon(Icons.shuffle));
    expect(shuffleSemantics.flagsCollection.isEnabled, ui.Tristate.isTrue);

    await tester.tap(find.byIcon(Icons.shuffle));
    await tester.pump();

    expect(repository.commands, contains('setShuffleMode:true'));
  });

  testWidgets(
    'tapping repeat cycles off -> queue -> track and back, swapping icons',
    (tester) async {
      setUpMediaView(tester);
      await tester.pumpWidget(mediaHarness(controller));
      await tester.pump();

      expect(find.byIcon(Icons.repeat), findsOneWidget);

      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();
      expect(repository.commands, contains('setRepeatMode:queue'));
      expect(find.byIcon(Icons.repeat), findsOneWidget);

      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();
      expect(repository.commands, contains('setRepeatMode:track'));
      expect(find.byIcon(Icons.repeat_one), findsOneWidget);

      await tester.tap(find.byIcon(Icons.repeat_one));
      await tester.pump();
      expect(repository.commands, contains('setRepeatMode:off'));
      expect(find.byIcon(Icons.repeat), findsOneWidget);
    },
  );

  testWidgets('collapses and expands the queue sidebar', (tester) async {
    setUpMediaView(tester);
    await tester.pumpWidget(mediaHarness(controller));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets(
    'opens the collections page and shows an unavailable track badge',
    (tester) async {
      setUpMediaView(tester);
      await tester.pumpWidget(mediaHarness(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('BIBLIOTHEK'));
      await tester.pumpAndSettle();

      expect(find.text('GHOST TRACK', findRichText: true), findsNothing);
      expect(find.textContaining('Ghost Track'), findsOneWidget);
      expect(find.text('NICHT VERFÜGBAR'), findsOneWidget);

      // The unavailable row must not be offered for playback.
      await tester.tap(find.textContaining('Ghost Track'));
      await tester.pump();
      expect(repository.commands, isEmpty);
    },
  );

  testWidgets('the Play icon on a Collections overview row actually starts the '
      'playlist - listPlaylists() never returns entries, so this has to '
      'fetch them first', (tester) async {
    repository.playlists = const [
      MediaPlaylist(id: 7, name: 'Drive', entries: []),
    ];
    repository.playlistDetails[7] = const MediaPlaylist(
      id: 7,
      name: 'Drive',
      entries: [
        MediaPlaylistEntry(
          id: 1,
          playlistId: 7,
          mediaId: 1,
          position: 0,
          track: _trackA,
        ),
      ],
    );
    setUpMediaView(tester);
    await tester.pumpWidget(mediaHarness(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SAMMLUNGEN'));
    await tester.pumpAndSettle();

    // Only the playlist row's trailing button shows this icon here - the
    // main player (with its own play/pause icon) isn't on screen while
    // the Collections overview is.
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    expect(repository.commands, contains('playPlaylist:7'));
  });

  testWidgets(
    'starting a playlist from its detail page navigates back to the player',
    (tester) async {
      repository.playlists = const [
        MediaPlaylist(id: 7, name: 'Drive', entries: []),
      ];
      repository.playlistDetails[7] = const MediaPlaylist(
        id: 7,
        name: 'Drive',
        entries: [
          MediaPlaylistEntry(
            id: 1,
            playlistId: 7,
            mediaId: 1,
            position: 0,
            track: _trackA,
          ),
        ],
      );
      setUpMediaView(tester);
      await tester.pumpWidget(mediaHarness(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SAMMLUNGEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Playlist Drive öffnen'));
      await tester.pumpAndSettle();

      expect(find.text('PLAYLIST STARTEN'), findsOneWidget);
      await tester.tap(find.text('PLAYLIST STARTEN'));
      await tester.pumpAndSettle();

      expect(repository.commands, contains('playPlaylist:7'));
      // Back on the player - the playlist detail page is gone (its "quick
      // actions" sidebar button also reads "SAMMLUNGEN", so that text alone
      // isn't a useful signal here).
      expect(find.text('PLAYLIST STARTEN'), findsNothing);
      expect(find.text('DRIVE'), findsNothing);
    },
  );

  testWidgets('creating a playlist hands off to the add-entries view', (
    tester,
  ) async {
    setUpMediaView(tester);
    await tester.pumpWidget(mediaHarness(controller));
    await tester.pumpAndSettle();

    // "Erstellen" now lives inside "Sammlungen", not in the queue sidebar.
    await tester.tap(find.text('SAMMLUNGEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // OnScreenTextField is readOnly (bound to the on-screen keyboard, not
    // the platform IME), so tester.enterText can't drive it - mutate the
    // bound controller directly instead, the same way a key tap would.
    tester
            .widget<OnScreenTextField>(find.byType(OnScreenTextField))
            .controller
            .text =
        'Drive';
    await tester.pump();
    // There's no separate "create" button anymore - submitting via the
    // on-screen keyboard's Fertig key is the only way to create the
    // playlist now.
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();

    expect(repository.playlists, hasLength(1));
    expect(repository.playlists.first.name, 'Drive');
    // Handed off straight to adding tracks - the library search field for
    // that flow should now be visible.
    expect(find.byType(OnScreenTextField), findsWidgets);
  });

  testWidgets(
    'tapping an already-added track again shows a hint instead of adding '
    'it a second time',
    (tester) async {
      setUpMediaView(tester);
      await tester.pumpWidget(mediaHarness(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SAMMLUNGEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      tester
              .widget<OnScreenTextField>(find.byType(OnScreenTextField))
              .controller
              .text =
          'Drive';
      await tester.pump();
      await tester.tap(find.text('Fertig'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Neon Dreams'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.textContaining('Neon Dreams'));
      await tester.pumpAndSettle();

      expect(find.text('Titel ist bereits in der Playlist'), findsOneWidget);

      // Let the hint's own auto-dismiss timer fire before the test ends -
      // otherwise the harness flags it as a leaked pending Timer.
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets('a player stream failure shows the offline banner', (
    tester,
  ) async {
    setUpMediaView(tester);
    await tester.pumpWidget(mediaHarness(controller));
    await tester.pump();

    repository.playerEventsController.addError(Exception('connection lost'));
    await tester.pump();

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);

    // Retrying calls back into the repository without throwing.
    await tester.tap(find.text('ERNEUT VERSUCHEN'));
    await tester.pump();
    expect(repository.reconnectCallCount, greaterThan(0));
  });

  testWidgets('a detected USB volume shows the import banner, and Übernehmen '
      'triggers the import', (tester) async {
    setUpMediaView(tester);
    await tester.pumpWidget(mediaHarness(controller));
    await tester.pump();

    repository.libraryEventsController.add(
      const LibraryScanEvent(
        kind: LibraryScanEventKind.musicFound,
        scanId: 0,
        processed: 0,
        imported: 0,
        path: '',
        message: '',
        sourceLabel: 'MUSIK',
        sourcePath: '/media/usb0',
        matchingFiles: 3,
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.usb), findsOneWidget);
    expect(find.textContaining('MUSIK'), findsOneWidget);

    await tester.tap(find.text('ÜBERNEHMEN'));
    await tester.pump();

    // The banner is gone immediately - acceptPendingImport() clears the
    // prompt before it even calls the backend.
    expect(find.byIcon(Icons.usb), findsNothing);

    await repository.importController.close();
    await repository.rescanController.close();
    await tester.pumpAndSettle();
  });

  testWidgets('dismissing the USB import banner imports nothing', (
    tester,
  ) async {
    setUpMediaView(tester);
    await tester.pumpWidget(mediaHarness(controller));
    await tester.pump();

    repository.libraryEventsController.add(
      const LibraryScanEvent(
        kind: LibraryScanEventKind.musicFound,
        scanId: 0,
        processed: 0,
        imported: 0,
        path: '',
        message: '',
        sourceLabel: 'MUSIK',
        sourcePath: '/media/usb0',
        matchingFiles: 3,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('SCHLIESSEN'));
    await tester.pump();

    expect(find.byIcon(Icons.usb), findsNothing);
    expect(repository.commands, isEmpty);
  });
}
