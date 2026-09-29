import 'dart:async';

import 'package:carnine_frontend/app/ui_readiness.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

/// Fails with the queued errors, one per call, then succeeds.
class FakeBackend {
  final List<Object> errors = <Object>[];
  int calls = 0;

  Future<void> report() async {
    calls++;
    if (errors.isNotEmpty) {
      throw errors.removeAt(0);
    }
  }
}

const _unavailable = GrpcError.unavailable('connection refused');

void main() {
  late FakeBackend backend;
  late int notified;
  late UiReadinessReporter reporter;

  setUp(() {
    backend = FakeBackend();
    notified = 0;
    reporter = UiReadinessReporter(
      reportToBackend: backend.report,
      notifySystemd: () async => notified++,
    );
  });

  test('reports once and tells systemd when the backend is up', () async {
    expect(await reporter.report(), isTrue);

    expect(backend.calls, 1);
    expect(notified, 1);
  });

  test('retries while the backend is not reachable yet (#54)', () {
    fakeAsync((async) {
      backend.errors.addAll([_unavailable, _unavailable, _unavailable]);
      bool? result;

      unawaited(reporter.report().then((value) => result = value));
      async.elapse(const Duration(seconds: 2));

      expect(backend.calls, 4);
      expect(notified, 1);
      expect(result, isTrue);
    });
  });

  test('gives up in time for systemd to restart the frontend', () {
    fakeAsync((async) {
      backend.errors.addAll(List<Object>.filled(1000, _unavailable));
      bool? result;

      unawaited(reporter.report().then((value) => result = value));
      async.elapse(UiReadinessReporter.defaultGiveUpAfter);
      async.elapse(const Duration(seconds: 3));

      expect(result, isFalse);
      expect(notified, 0);
      final calls = backend.calls;
      async.elapse(const Duration(minutes: 1));
      expect(backend.calls, calls);
    });
  });

  test('the give-up time stays below the unit start timeout', () {
    const timeoutStartSec = Duration(seconds: 30);
    const lastDelay = Duration(seconds: 2);
    // Frames waited for before reporting, see _uiReadyMaxWait in main.dart.
    const readyWait = Duration(seconds: 5);

    expect(
      UiReadinessReporter.defaultGiveUpAfter + lastDelay + readyWait,
      lessThan(timeoutStartSec),
    );
  });

  test('does not retry other errors', () async {
    backend.errors.add(const GrpcError.unimplemented('reportUiReady'));

    expect(await reporter.report(), isFalse);
    expect(backend.calls, 1);
    expect(notified, 0);
  });

  test('does not retry a refusal from the backend', () async {
    backend.errors.add(StateError('not ready'));

    expect(await reporter.report(), isFalse);
    expect(backend.calls, 1);
  });
}
