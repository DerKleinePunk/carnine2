import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/domain/models/player_event_update.dart';
import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_media_repository.dart';
import '../../fakes/media_test_harness.dart';

/// A row of the queue and the gap below it.
const double _row = 68;

MediaLibraryTrack _track(int number) => MediaLibraryTrack(
  id: number,
  sourceId: 1,
  path: '/music/$number.mp3',
  title: 'Titel $number',
  artist: 'Interpret',
  duration: const Duration(minutes: 3),
  availability: MediaAvailability.available,
);

List<MediaLibraryTrack> _tracks(int count) => [
  for (var i = 1; i <= count; i++) _track(i),
];

/// The queue of the player: the only list with rows of 68.
final Finder _queueList = find.byWidgetPredicate(
  (widget) => widget is ListView && widget.itemExtent == _row,
);

/// [text] in a row of the queue; the player shows the running title too.
Finder _inQueue(String text) =>
    find.descendant(of: _queueList, matching: find.text(text));

void main() {
  late FakeMediaRepository repository;
  late MediaController controller;

  setUp(() {
    repository = FakeMediaRepository();
    controller = MediaController(
      repository: repository,
      heartbeatInterval: null,
    );
  });

  tearDown(() => controller.dispose());

  ScrollPosition position(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(of: _queueList, matching: find.byType(Scrollable)),
      )
      .position;

  /// Where the row of track [number] would start if it were scrolled to be
  /// the second row, held inside the list's range.
  double secondRow(WidgetTester tester, int number) =>
      ((number - 2) * _row).clamp(0.0, position(tester).maxScrollExtent);

  /// The backend says track [number] runs now (paused, so no ticker runs on).
  void play(int number) {
    repository.playerEventsController.add(
      PlayerEventUpdate(
        kind: PlayerEventKind.snapshot,
        state: PlayerSnapshot(
          status: PlaybackStatus.paused,
          mediaPath: '/music/$number.mp3',
          position: Duration.zero,
        ),
        message: '',
      ),
    );
  }

  /// Media opened, then a playlist of [count] tracks loaded and track
  /// [number] running.
  Future<void> open(
    WidgetTester tester, {
    int count = 50,
    int number = 1,
  }) async {
    setUpMediaView(tester);
    await tester.pumpWidget(mediaHarness(controller));
    await tester.pump();
    await controller.player.playPlaylist(
      const MediaPlaylist(id: 1, name: 'Alle Lieder', entries: []),
      _tracks(count),
    );
    play(number);
    await tester.pumpAndSettle();
  }

  group('the running track is the second row (#216)', () {
    testWidgets('after loading the queue', (tester) async {
      await open(tester, number: 20);

      expect(position(tester).pixels, secondRow(tester, 20));
      expect(_inQueue('TITEL 19'), findsOneWidget, reason: 'one before it');
      expect(_inQueue('TITEL 20'), findsOneWidget);
    });

    testWidgets('the first track stands at the top', (tester) async {
      await open(tester);

      expect(position(tester).pixels, 0);
    });

    testWidgets('the last track: as far down as the list goes', (tester) async {
      await open(tester, number: 50);

      expect(position(tester).pixels, position(tester).maxScrollExtent);
      expect(_inQueue('TITEL 50'), findsOneWidget);
    });

    testWidgets('a short list that fits does not scroll', (tester) async {
      await open(tester, count: 3, number: 3);

      expect(position(tester).maxScrollExtent, 0);
      expect(position(tester).pixels, 0);
    });
  });

  group('following the running track', () {
    testWidgets('far off it jumps, at once', (tester) async {
      await open(tester, number: 2);

      play(40);
      // The event, the rebuild with the jump: no frames of a glide between.
      await tester.pump();
      await tester.pump();
      expect(position(tester).pixels, secondRow(tester, 40));

      await tester.pump();
      expect(_inQueue('TITEL 40'), findsOneWidget);
    });

    testWidgets('close by it glides there in 200 ms', (tester) async {
      await open(tester, number: 20);
      final before = position(tester).pixels;

      play(21);
      // The event, the rebuild, then the glide starts.
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final midway = position(tester).pixels;
      expect(midway, greaterThan(before));
      expect(midway, lessThan(secondRow(tester, 21)));

      await tester.pump(const Duration(milliseconds: 200));
      expect(position(tester).pixels, secondRow(tester, 21));
    });

    testWidgets('a shuffle jump back up the list follows too', (tester) async {
      await open(tester, number: 40);

      play(3);
      await tester.pumpAndSettle();

      expect(position(tester).pixels, secondRow(tester, 3));
      expect(_inQueue('TITEL 3'), findsOneWidget);
    });

    testWidgets('a new playlist goes to its running track', (tester) async {
      await open(tester, number: 40);

      await controller.player.playPlaylist(
        const MediaPlaylist(id: 2, name: 'Kurz', entries: []),
        [for (var i = 101; i <= 130; i++) _track(i)],
      );
      play(105);
      await tester.pumpAndSettle();

      expect(position(tester).pixels, secondRow(tester, 5));
      expect(_inQueue('TITEL 105'), findsOneWidget);
    });
  });

  group('a list the user scrolled', () {
    testWidgets('stays put until the next track', (tester) async {
      await open(tester, number: 20);

      await tester.drag(_queueList, const Offset(0, 300));
      await tester.pumpAndSettle();
      final scrolled = position(tester).pixels;
      expect(scrolled, lessThan(secondRow(tester, 20)));

      // Pausing and resuming the same track rebuilds, but changes nothing.
      play(20);
      await tester.pumpAndSettle();
      expect(position(tester).pixels, scrolled);

      play(30);
      await tester.pumpAndSettle();
      expect(position(tester).pixels, secondRow(tester, 30));
    });

    testWidgets('comes back when the queue is expanded again', (tester) async {
      await open(tester, number: 20);
      await tester.drag(_queueList, const Offset(0, 300));
      await tester.pumpAndSettle();

      controller.toggleQueueExpanded();
      await tester.pumpAndSettle();
      controller.toggleQueueExpanded();
      await tester.pumpAndSettle();

      expect(position(tester).pixels, secondRow(tester, 20));
    });
  });
}
