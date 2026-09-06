import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/player_event_update.dart';
import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/play_pause_button.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/track_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_media_repository.dart';
import '../../fakes/media_test_harness.dart';

const _trackA = MediaLibraryTrack(
  id: 1,
  sourceId: 1,
  path: '/music/a.mp3',
  title: 'A',
  artist: 'Artist A',
  duration: Duration(minutes: 3),
  availability: MediaAvailability.available,
);

const _trackLongTitle = MediaLibraryTrack(
  id: 2,
  sourceId: 1,
  path: '/music/long.mp3',
  title:
      'This Is An Absurdly Long Song Title That Would Never Fit On One '
      'Line At A Normal Font Size',
  artist: 'Artist With A Very Long Name Too',
  duration: Duration(minutes: 4),
  availability: MediaAvailability.available,
);

Future<void> _pumpAt(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  required MediaController controller,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: mediaHarness(controller),
    ),
  );
  await tester.pump();
}

void main() {
  late FakeMediaRepository repository;

  setUp(() {
    repository = FakeMediaRepository()..library = const [_trackA];
  });

  testWidgets(
    'a very long track title shrinks to fit one line instead of pushing '
    'the transport controls off-screen',
    (tester) async {
      final longTitleRepository = FakeMediaRepository()
        ..library = const [_trackLongTitle];
      final controller = MediaController(repository: longTitleRepository);
      addTearDown(controller.dispose);

      await _pumpAt(
        tester,
        size: const Size(1024, 600),
        textScale: 1.0,
        controller: controller,
      );

      longTitleRepository.playerEventsController.add(
        PlayerEventUpdate(
          kind: PlayerEventKind.snapshot,
          state: const PlayerSnapshot(
            status: PlaybackStatus.paused,
            mediaPath: '/music/long.mp3',
            position: Duration.zero,
          ),
          message: 'current player state',
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      // The play button must still be fully on-screen, not pushed down by a
      // wrapped title.
      final playButtonRect = tester.getRect(find.byType(PlayPauseButton));
      expect(playButtonRect.bottom, lessThanOrEqualTo(600));

      // The full title is still there - shrunk to fit, never truncated with
      // an ellipsis - and kept to a single line. Scoped to TrackInfo: the
      // same title also appears as a queue row, so a bare find.text() would
      // match more than one widget.
      final titleText = tester.widget<Text>(
        find.descendant(
          of: find.byType(TrackInfo),
          matching: find.text(_trackLongTitle.title.toUpperCase()),
        ),
      );
      expect(titleText.maxLines, 1);
      expect(titleText.data, _trackLongTitle.title.toUpperCase());
    },
  );

  for (final size in [const Size(1024, 600), const Size(800, 480)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'the player page renders without overflow at $size, ${scale}x text',
        (tester) async {
          final controller = MediaController(repository: repository);
          addTearDown(controller.dispose);

          await _pumpAt(
            tester,
            size: size,
            textScale: scale,
            controller: controller,
          );

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'the collections page renders without overflow at $size, ${scale}x text',
        (tester) async {
          final controller = MediaController(repository: repository);
          addTearDown(controller.dispose);

          await _pumpAt(
            tester,
            size: size,
            textScale: scale,
            controller: controller,
          );
          controller.showLibraryAction(MediaLibraryAction.collections);
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'the create playlist page renders without overflow at $size, ${scale}x text',
        (tester) async {
          final controller = MediaController(repository: repository);
          addTearDown(controller.dispose);

          await _pumpAt(
            tester,
            size: size,
            textScale: scale,
            controller: controller,
          );
          controller.showLibraryAction(MediaLibraryAction.create);
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'the library page renders without overflow at $size, ${scale}x text',
        (tester) async {
          final controller = MediaController(repository: repository);
          addTearDown(controller.dispose);

          await _pumpAt(
            tester,
            size: size,
            textScale: scale,
            controller: controller,
          );
          controller.showLibraryAction(MediaLibraryAction.library);
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
