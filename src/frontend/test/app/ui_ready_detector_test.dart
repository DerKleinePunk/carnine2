import 'dart:ui' show FrameTiming;

import 'package:carnine_frontend/app/ui_ready_detector.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/scheduler.dart' show TimingsCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

FrameTiming _timing() => FrameTiming(
  vsyncStart: 0,
  buildStart: 1,
  buildFinish: 2,
  rasterStart: 3,
  rasterFinish: 4,
  rasterFinishWallTime: 4,
);

class _Binding {
  final List<TimingsCallback> callbacks = <TimingsCallback>[];
  int removed = 0;

  void add(TimingsCallback callback) => callbacks.add(callback);

  void remove(TimingsCallback callback) {
    if (callbacks.remove(callback)) removed++;
  }

  void report(int frames) {
    final timings = List<FrameTiming>.generate(frames, (_) => _timing());
    for (final callback in List<TimingsCallback>.of(callbacks)) {
      callback(timings);
    }
  }
}

void main() {
  late _Binding binding;
  late int readyCalls;
  late List<LogRecord> records;

  UiReadyDetector detector({Duration maxWait = const Duration(seconds: 5)}) {
    final logger = Logger.detached('UiReadinessTest')..level = Level.ALL;
    logger.onRecord.listen(records.add);
    return UiReadyDetector(
      addTimingsCallback: binding.add,
      removeTimingsCallback: binding.remove,
      onReady: () => readyCalls++,
      maxWait: maxWait,
      logger: logger,
    );
  }

  setUp(() {
    binding = _Binding();
    readyCalls = 0;
    records = <LogRecord>[];
  });

  test('the first frame timing reports ready, once', () {
    fakeAsync((async) {
      final subject = detector()..start();
      expect(readyCalls, 0);
      binding.report(1);
      expect(readyCalls, 1);
      expect(subject.finished, isTrue);
      binding.report(3);
      async.elapse(const Duration(seconds: 10));
      expect(readyCalls, 1, reason: 'neither later frames nor the timer');
      expect(binding.callbacks, isEmpty);
      expect(binding.removed, 1);
      expect(
        records.single.message,
        startsWith('UI ready: first frame on screen after'),
      );
    });
  });

  test('one frame is enough, no frames are forced or waited for', () {
    fakeAsync((async) {
      detector().start();
      async.elapse(const Duration(milliseconds: 300));
      expect(readyCalls, 0, reason: 'nothing happens without a frame');
      binding.report(1);
      expect(readyCalls, 1);
    });
  });

  test('without any frame timing, ready comes after maxWait', () {
    fakeAsync((async) {
      detector(maxWait: const Duration(seconds: 5)).start();
      async.elapse(const Duration(milliseconds: 4999));
      expect(readyCalls, 0);
      async.elapse(const Duration(milliseconds: 1));
      expect(readyCalls, 1);
      expect(binding.callbacks, isEmpty);
      expect(records.single.level, Level.WARNING);
      binding.report(1);
      expect(readyCalls, 1, reason: 'a late frame does not report again');
    });
  });

  test('an empty batch of timings is not a frame', () {
    fakeAsync((async) {
      detector().start();
      binding.report(0);
      expect(readyCalls, 0);
      binding.report(1);
      expect(readyCalls, 1);
    });
  });

  test('starting twice registers once', () {
    fakeAsync((async) {
      detector()
        ..start()
        ..start();
      expect(binding.callbacks, hasLength(1));
      binding.report(1);
      expect(readyCalls, 1);
    });
  });
}
