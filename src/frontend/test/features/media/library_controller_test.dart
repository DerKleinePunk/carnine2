import 'package:carnine_frontend/features/media/domain/media_backend_exception.dart';
import 'package:carnine_frontend/features/media/domain/models/library_scan_event.dart';
import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/presentation/library_controller.dart';
import 'package:carnine_frontend/features/media/presentation/models/media_view_state.dart';
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
  late LibraryController controller;

  setUp(() {
    repository = FakeMediaRepository();
    controller = LibraryController(repository: repository);
  });

  tearDown(() {
    controller.dispose();
  });

  test('loads the library and lands in the ready state', () async {
    repository.library = const [_trackA];

    await controller.start();

    expect(controller.state.status, MediaViewStatus.ready);
    expect(controller.results, [_trackA]);
  });

  test('an empty library lands in the empty state', () async {
    await controller.start();

    expect(controller.state.status, MediaViewStatus.empty);
  });

  test('an offline failure surfaces the offline state and reports it',
      () async {
    repository.nextError =
        const MediaBackendException(MediaErrorKind.offline, 'unreachable');
    var reported = false;
    controller = LibraryController(
      repository: repository,
      onStreamFailure: (_) => reported = true,
    );

    await controller.start();

    expect(controller.state.status, MediaViewStatus.offline);
    expect(reported, isTrue);
  });

  test('retry recovers after the backend comes back', () async {
    repository.nextError =
        const MediaBackendException(MediaErrorKind.offline, 'unreachable');
    await controller.start();
    expect(controller.state.status, MediaViewStatus.offline);

    repository.library = const [_trackA];
    await controller.retry();

    expect(controller.state.status, MediaViewStatus.ready);
  });

  test('query changes are debounced to a single search', () async {
    repository.library = const [_trackA];
    await controller.start();

    controller.onQueryChanged('a');
    controller.onQueryChanged('ar');
    controller.onQueryChanged('art');
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(controller.query, 'art');
    expect(controller.results, [_trackA]);
  });

  test('scan_completed on the library stream re-runs the current query',
      () async {
    await controller.start();
    expect(controller.results, isEmpty);

    repository.library = const [_trackA];
    repository.libraryEventsController.add(
      const LibraryScanEvent(
        kind: LibraryScanEventKind.scanCompleted,
        scanId: 1,
        processed: 1,
        imported: 1,
        path: '',
        message: '',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.results, [_trackA]);
    expect(controller.isScanning, isFalse);
  });

  test('rescan shows the scanning state before the future resolves', () async {
    await controller.start();

    final future = controller.rescan();
    expect(controller.isScanning, isTrue);

    repository.rescanController.close();
    await future;

    expect(controller.isScanning, isFalse);
  });
}
