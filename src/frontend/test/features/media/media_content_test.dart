import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
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

  testWidgets('shows the current track once the player emits a snapshot',
      (tester) async {
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

  testWidgets('play/pause taps issue the expected backend commands',
      (tester) async {
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

  testWidgets('shuffle and repeat are visible but permanently disabled',
      (tester) async {
    setUpMediaView(tester);
    await tester.pumpWidget(mediaHarness(controller));
    await tester.pump();

    final shuffleSemantics = tester.getSemantics(find.byIcon(Icons.shuffle));
    final repeatSemantics = tester.getSemantics(find.byIcon(Icons.repeat));

    expect(shuffleSemantics.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(repeatSemantics.flagsCollection.isEnabled, ui.Tristate.isFalse);

    await tester.tap(find.byIcon(Icons.shuffle));
    await tester.pump();

    expect(repository.commands, isEmpty);
  });

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

  testWidgets('opens the collections page and shows an unavailable track badge',
      (tester) async {
    setUpMediaView(tester);
    await tester.pumpWidget(mediaHarness(controller));
    await tester.pumpAndSettle();

    // Not find.byIcon(Icons.library_music): the same icon is also the
    // empty-state glyph for the (still empty) queue sidebar next to it.
    await tester.tap(find.text('SAMMLUNGEN'));
    await tester.pumpAndSettle();

    expect(find.text('GHOST TRACK', findRichText: true), findsNothing);
    expect(find.textContaining('Ghost Track'), findsOneWidget);
    expect(find.text('NICHT VERFÜGBAR'), findsOneWidget);

    // The unavailable row must not be offered for playback.
    await tester.tap(find.textContaining('Ghost Track'));
    await tester.pump();
    expect(repository.commands, isEmpty);
  });

  testWidgets('creating a playlist hands off to the add-entries view',
      (tester) async {
    setUpMediaView(tester);
    await tester.pumpWidget(mediaHarness(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // OnScreenTextField is readOnly (bound to the on-screen keyboard, not
    // the platform IME), so tester.enterText can't drive it - mutate the
    // bound controller directly instead, the same way a key tap would.
    tester
        .widget<OnScreenTextField>(find.byType(OnScreenTextField))
        .controller
        .text = 'Drive';
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

  testWidgets('a player stream failure shows the offline banner',
      (tester) async {
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
}
