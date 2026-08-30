import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
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

  for (final size in [const Size(1024, 600), const Size(800, 480)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'the player page renders without overflow at $size, ${scale}x text',
        (tester) async {
          final controller = MediaController(repository: repository);
          addTearDown(controller.dispose);

          await _pumpAt(tester,
              size: size, textScale: scale, controller: controller);

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'the collections page renders without overflow at $size, ${scale}x text',
        (tester) async {
          final controller = MediaController(repository: repository);
          addTearDown(controller.dispose);

          await _pumpAt(tester,
              size: size, textScale: scale, controller: controller);
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

          await _pumpAt(tester,
              size: size, textScale: scale, controller: controller);
          controller.showLibraryAction(MediaLibraryAction.create);
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
