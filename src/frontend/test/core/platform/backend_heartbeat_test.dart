import 'dart:async';

import 'package:carnine_frontend/core/platform/backend_heartbeat.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const interval = Duration(seconds: 5);
  const timeout = Duration(seconds: 3);

  test('checks once per interval while the backend answers', () {
    fakeAsync((async) {
      var checks = 0;
      final failures = <Object>[];
      final heartbeat = BackendHeartbeat(
        check: () async => checks++,
        onFailure: failures.add,
        interval: interval,
        timeout: timeout,
      )..start();

      async.elapse(const Duration(seconds: 16));

      expect(checks, 3);
      expect(failures, isEmpty);
      expect(heartbeat.isRunning, isTrue);
      heartbeat.stop();
    });
  });

  test('a failing check is reported once and stops the heartbeat', () {
    fakeAsync((async) {
      var checks = 0;
      final failures = <Object>[];
      final heartbeat = BackendHeartbeat(
        check: () async {
          checks++;
          throw StateError('unavailable');
        },
        onFailure: failures.add,
        interval: interval,
        timeout: timeout,
      )..start();

      async.elapse(const Duration(seconds: 30));

      expect(checks, 1);
      expect(failures, hasLength(1));
      expect(heartbeat.isRunning, isFalse);
    });
  });

  // The hang of #58: the call neither returns nor fails.
  test('a check that never returns fails after the timeout', () {
    fakeAsync((async) {
      final failures = <Object>[];
      BackendHeartbeat(
        check: () => Completer<void>().future,
        onFailure: failures.add,
        interval: interval,
        timeout: timeout,
      ).start();

      async.elapse(interval + timeout - const Duration(milliseconds: 1));
      expect(failures, isEmpty);

      async.elapse(const Duration(milliseconds: 1));
      expect(failures.single, isA<TimeoutException>());
    });
  });

  test('a slow check delays the next one instead of overlapping it', () {
    fakeAsync((async) {
      var running = 0;
      var mostAtOnce = 0;
      final heartbeat = BackendHeartbeat(
        check: () async {
          running++;
          mostAtOnce = running > mostAtOnce ? running : mostAtOnce;
          await Future<void>.delayed(const Duration(seconds: 2));
          running--;
        },
        onFailure: (_) {},
        interval: interval,
        timeout: timeout,
      )..start();

      async.elapse(const Duration(seconds: 30));

      expect(mostAtOnce, 1);
      heartbeat.stop();
    });
  });

  test('a failure of a stopped heartbeat is not reported', () {
    fakeAsync((async) {
      final pending = Completer<void>();
      final failures = <Object>[];
      final heartbeat = BackendHeartbeat(
        check: () => pending.future,
        onFailure: failures.add,
        interval: interval,
        timeout: timeout,
      )..start();

      async.elapse(interval);
      heartbeat.stop();
      pending.completeError(StateError('late'));
      async.elapse(timeout);

      expect(failures, isEmpty);
    });
  });
}
