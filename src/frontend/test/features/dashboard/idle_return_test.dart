import 'package:carnine_frontend/features/dashboard/presentation/idle_return.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const minute = Duration(seconds: 60);

  test('59 seconds without a touch: nothing, at 60 it fires', () {
    fakeAsync((async) {
      var idle = 0;
      final idleReturn = IdleReturn(
        after: minute,
        isEnabled: () => true,
        onIdle: () => idle++,
      )..sync();

      async.elapse(const Duration(seconds: 59));
      expect(idle, 0);

      async.elapse(const Duration(seconds: 1));
      expect(idle, 1);
      idleReturn.dispose();
    });
  });

  test('a touch at 30 seconds starts the 60 again', () {
    fakeAsync((async) {
      var idle = 0;
      final idleReturn = IdleReturn(
        after: minute,
        isEnabled: () => true,
        onIdle: () => idle++,
      )..sync();

      async.elapse(const Duration(seconds: 30));
      idleReturn.touch();
      async.elapse(const Duration(seconds: 59));
      expect(idle, 0);

      async.elapse(const Duration(seconds: 1));
      expect(idle, 1);
      idleReturn.dispose();
    });
  });

  test('every touch pushes it back, also a long series', () {
    fakeAsync((async) {
      var idle = 0;
      final idleReturn = IdleReturn(
        after: minute,
        isEnabled: () => true,
        onIdle: () => idle++,
      )..sync();

      for (var i = 0; i < 10; i++) {
        async.elapse(const Duration(seconds: 50));
        idleReturn.touch();
      }

      expect(idle, 0);
      idleReturn.dispose();
    });
  });

  test('without the trade fair mode nothing ever fires, touches or not', () {
    fakeAsync((async) {
      var idle = 0;
      final idleReturn = IdleReturn(
        after: minute,
        isEnabled: () => false,
        onIdle: () => idle++,
      )..sync();
      idleReturn.touch();

      async.elapse(const Duration(minutes: 10));

      expect(idle, 0);
      expect(idleReturn.isRunning, isFalse);
      idleReturn.dispose();
    });
  });

  test('the mode switching on starts the time, switching off stops it', () {
    fakeAsync((async) {
      var enabled = false;
      var idle = 0;
      final idleReturn = IdleReturn(
        after: minute,
        isEnabled: () => enabled,
        onIdle: () => idle++,
      )..sync();
      async.elapse(const Duration(minutes: 5));
      expect(idle, 0);

      enabled = true;
      idleReturn.sync();
      async.elapse(const Duration(seconds: 59));
      expect(idle, 0);
      async.elapse(const Duration(seconds: 1));
      expect(idle, 1);

      enabled = false;
      idleReturn.sync();
      async.elapse(const Duration(minutes: 5));
      expect(idle, 1);
      idleReturn.dispose();
    });
  });

  test('a status report in between does not push the time back', () {
    fakeAsync((async) {
      var idle = 0;
      final idleReturn = IdleReturn(
        after: minute,
        isEnabled: () => true,
        onIdle: () => idle++,
      )..sync();

      // The backend answers every 3 seconds.
      for (var i = 0; i < 19; i++) {
        async.elapse(const Duration(seconds: 3));
        idleReturn.sync();
      }
      expect(idle, 0);

      async.elapse(const Duration(seconds: 3));
      expect(idle, 1);
      idleReturn.dispose();
    });
  });

  test('restart gives another full minute', () {
    fakeAsync((async) {
      var idle = 0;
      late final IdleReturn idleReturn;
      idleReturn = IdleReturn(
        after: minute,
        isEnabled: () => true,
        onIdle: () {
          idle++;
          if (idle == 1) {
            idleReturn.restart();
          }
        },
      )..sync();

      async.elapse(minute);
      expect(idle, 1);
      async.elapse(const Duration(seconds: 59));
      expect(idle, 1);
      async.elapse(const Duration(seconds: 1));
      expect(idle, 2);
      idleReturn.dispose();
    });
  });

  test('dispose stops it', () {
    fakeAsync((async) {
      var idle = 0;
      IdleReturn(after: minute, isEnabled: () => true, onIdle: () => idle++)
        ..sync()
        ..dispose();

      async.elapse(const Duration(minutes: 5));

      expect(idle, 0);
    });
  });
}
