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

  group('a backend that stops answering (#58)', () {
    late FakeMediaRepository frozenRepository;
    late MediaController frozenController;

    setUp(() async {
      frozenRepository = FakeMediaRepository();
      frozenController = MediaController(
        repository: frozenRepository,
        heartbeatInterval: const Duration(milliseconds: 200),
        heartbeatTimeout: const Duration(milliseconds: 100),
      );
      await frozenController.start();
    });

    tearDown(() => frozenController.dispose());

    Future<void> waitFor(bool Function() condition) async {
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (!condition()) {
        expect(DateTime.now().isBefore(deadline), isTrue, reason: 'timeout');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    test('stays online while the backend answers', () async {
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(frozenRepository.checkAliveCallCount, greaterThanOrEqualTo(2));
      expect(frozenController.connection, MediaConnectionStatus.online);
      expect(frozenRepository.reconnectCallCount, 0);
    });

    test('goes offline, stays offline and comes back after the thaw', () async {
      // Frozen: the streams stay silent and no call is ever answered.
      var frozen = true;
      frozenRepository.onCheckAlive = () =>
          frozen ? Completer<void>().future : Future<void>.value();

      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(frozenController.connection, MediaConnectionStatus.offline);
      // The channel was closed hard, so the silent streams fail at once.
      expect(frozenRepository.reconnectCallCount, greaterThanOrEqualTo(1));

      // Reconnect attempts reach the frozen backend, but none may bring
      // the status back to online, not even for a moment.
      final statuses = <MediaConnectionStatus>[];
      void record() => statuses.add(frozenController.connection);
      frozenController.addListener(record);
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      frozenController.removeListener(record);
      expect(frozenRepository.reconnectCallCount, greaterThanOrEqualTo(3));
      expect(statuses, isNot(contains(MediaConnectionStatus.online)));
      expect(frozenController.connection, MediaConnectionStatus.offline);

      frozen = false;
      await waitFor(
        () => frozenController.connection == MediaConnectionStatus.online,
      );

      // Watched again after the thaw: a second freeze is noticed as well.
      frozen = true;
      await waitFor(
        () => frozenController.connection == MediaConnectionStatus.offline,
      );
    });
  });
}
