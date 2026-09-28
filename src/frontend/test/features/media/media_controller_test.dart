import 'dart:async';

import 'package:carnine_frontend/features/media/domain/models/library_scan_event.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_media_repository.dart';

/// Lets the library stream die right after [MediaController] re-opened it,
/// the way it does when the backend accepts the connection before it is
/// ready (#44).
class _EarlyReconnectRepository extends FakeMediaRepository {
  bool failNextLibrarySubscription = false;

  @override
  Stream<LibraryScanEvent> libraryEvents() {
    if (failNextLibrarySubscription) {
      failNextLibrarySubscription = false;
      scheduleMicrotask(
        () => libraryEventsController.addError(Exception('not ready yet')),
      );
    }
    return super.libraryEvents();
  }
}

// Real time rather than fakeAsync: cancelling a stream subscription returns a
// root-zone future that fakeAsync never completes. The backoff starts at
// 500 ms and doubles, so the second attempt runs 1.5 s after the failure.
void main() {
  late _EarlyReconnectRepository repository;
  late MediaController controller;

  setUp(() async {
    repository = _EarlyReconnectRepository();
    controller = MediaController(repository: repository);
    await controller.start();
    // start() opens the playlist stream unawaited; let it subscribe first.
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() => controller.dispose());

  test(
    'a stream failing during a reconnect triggers another reconnect',
    () async {
      expect(controller.connection, MediaConnectionStatus.online);

      repository.failNextLibrarySubscription = true;
      repository.playerEventsController.addError(Exception('backend gone'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.connection, MediaConnectionStatus.offline);

      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(repository.reconnectCallCount, 1);
      expect(controller.connection, MediaConnectionStatus.offline);

      await Future<void>.delayed(const Duration(milliseconds: 1000));
      expect(repository.reconnectCallCount, 2);
      expect(controller.connection, MediaConnectionStatus.online);
    },
  );

  test('a clean reconnect goes online after a single attempt', () async {
    repository.playerEventsController.addError(Exception('backend gone'));
    await Future<void>.delayed(const Duration(milliseconds: 800));

    expect(repository.reconnectCallCount, 1);
    expect(controller.connection, MediaConnectionStatus.online);

    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(repository.reconnectCallCount, 1);
  });
}
