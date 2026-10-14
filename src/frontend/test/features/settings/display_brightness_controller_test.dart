import 'dart:async';

import 'package:carnine_frontend/data/services/carnine_grpc_service.dart';
import 'package:carnine_frontend/features/settings/presentation/display_brightness_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart' as pb;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_display_brightness_store.dart';

DisplayBrightnessController _controller(FakeDisplayBrightnessStore store) {
  final controller = DisplayBrightnessController(store: store);
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('what the backend says', () {
    test('a display with a backlight shows its level', () async {
      final controller = _controller(FakeDisplayBrightnessStore(percent: 70));
      expect(controller.status, DisplayBrightnessStatus.loading);

      await controller.load();

      expect(controller.status, DisplayBrightnessStatus.ready);
      expect(controller.isUsable, isTrue);
      expect(controller.isNotConfigured, isFalse);
      expect(controller.percent, 70);
    });

    test('a display that is not modified is "not configured"', () async {
      final controller = _controller(
        FakeDisplayBrightnessStore(configured: false, available: false),
      );

      await controller.load();

      expect(controller.isNotConfigured, isTrue);
      expect(controller.isUsable, isFalse);
    });

    test(
      'a channel that cannot be driven is configured but not usable',
      () async {
        final controller = _controller(
          FakeDisplayBrightnessStore(available: false),
        );

        await controller.load();

        expect(controller.isNotConfigured, isFalse);
        expect(controller.isUsable, isFalse);
        expect(controller.setting?.configured, isTrue);
      },
    );

    test('a backend that is away is offline, and load tries again', () async {
      final store = FakeDisplayBrightnessStore()
        ..loadError = StateError('down');
      final controller = _controller(store);

      await controller.load();
      expect(controller.status, DisplayBrightnessStatus.offline);
      expect(controller.isNotConfigured, isFalse);

      store.loadError = null;
      await controller.load();
      expect(controller.status, DisplayBrightnessStatus.ready);
      expect(store.loads, 2);
    });

    test('asking again does not blank a page that has an answer', () async {
      final store = FakeDisplayBrightnessStore();
      final controller = _controller(store);
      await controller.load();

      final statuses = <DisplayBrightnessStatus>[];
      controller.addListener(() => statuses.add(controller.status));
      await controller.load();

      expect(statuses, everyElement(DisplayBrightnessStatus.ready));
    });
  });

  group('dragging', () {
    test('shows the level at once and sends about every 150 ms', () {
      fakeAsync((async) {
        final store = FakeDisplayBrightnessStore();
        final controller = DisplayBrightnessController(store: store);
        controller.load();
        async.flushMicrotasks();

        controller.drag(90);
        expect(controller.percent, 90);
        controller.drag(80);
        controller.drag(70);
        // Nothing yet: a drag does not send every step.
        expect(store.saves, isEmpty);

        async.elapse(const Duration(milliseconds: 150));
        async.flushMicrotasks();
        expect(store.saves, [70]);

        controller.drag(60);
        controller.drag(50);
        async.elapse(const Duration(milliseconds: 150));
        async.flushMicrotasks();
        expect(store.saves, [70, 50]);
        controller.dispose();
      });
    });

    test('is sent for good when it is let go, at once', () async {
      final store = FakeDisplayBrightnessStore();
      final controller = _controller(store);
      await controller.load();

      controller.drag(40);
      await controller.commit(35);

      expect(store.saves, [35]);
      expect(controller.percent, 35);
    });

    test('a level that was already sent is not sent again', () {
      fakeAsync((async) {
        final store = FakeDisplayBrightnessStore();
        final controller = DisplayBrightnessController(store: store);
        controller.load();
        async.flushMicrotasks();

        controller.drag(40);
        async.elapse(const Duration(milliseconds: 150));
        async.flushMicrotasks();
        controller.commit(40);
        async.flushMicrotasks();

        expect(store.saves, [40]);
        controller.dispose();
      });
    });

    test('while one call is on its way the next level waits for it', () {
      fakeAsync((async) {
        final store = FakeDisplayBrightnessStore()
          ..saveGate = Completer<void>();
        final controller = DisplayBrightnessController(store: store);
        controller.load();
        async.flushMicrotasks();

        controller.drag(60);
        async.elapse(const Duration(milliseconds: 150));
        async.flushMicrotasks();
        expect(store.saves, [60]);

        controller.drag(30);
        async.elapse(const Duration(milliseconds: 150));
        async.flushMicrotasks();
        // Still the first call; the second does not overtake it.
        expect(store.saves, [60]);

        store.saveGate?.complete();
        async.flushMicrotasks();
        expect(store.saves, [60, 30]);
        expect(controller.percent, 30);
        controller.dispose();
      });
    });

    test('a call that fails puts the slider back and says so', () async {
      final store = FakeDisplayBrightnessStore(percent: 80);
      final controller = _controller(store);
      await controller.load();
      store.saveError = StateError('no');

      await controller.commit(20);

      expect(controller.percent, 80);
      expect(controller.errorKey, AppTextKey.mediaCommandFailed);
    });

    test('the message goes away by itself', () {
      fakeAsync((async) {
        final store = FakeDisplayBrightnessStore();
        final controller = DisplayBrightnessController(store: store);
        controller.load();
        async.flushMicrotasks();
        store.saveError = StateError('no');

        controller.commit(20);
        async.flushMicrotasks();
        expect(controller.errorKey, isNotNull);

        async.elapse(const Duration(seconds: 5));
        expect(controller.errorKey, isNull);
        controller.dispose();
      });
    });
  });

  group('a display that cannot be set', () {
    test('ignores the slider', () async {
      for (final store in [
        FakeDisplayBrightnessStore(configured: false, available: false),
        FakeDisplayBrightnessStore(available: false),
      ]) {
        final controller = _controller(store);
        await controller.load();

        controller.drag(10);
        await controller.commit(10);

        expect(store.saves, isEmpty);
        expect(controller.percent, 100);
      }
    });
  });

  group('mapping from the backend', () {
    test('the three fields arrive as they are', () {
      final setting = CarnineGrpcService.displayBrightnessFrom(
        pb.DisplayBrightness(configured: true, available: false, percent: 0),
      );

      expect(setting.configured, isTrue);
      expect(setting.available, isFalse);
      expect(setting.percent, 0);
      expect(setting.isUsable, isFalse);
    });

    test('0 percent is the darkest level, a level and not "unset"', () {
      final setting = CarnineGrpcService.displayBrightnessFrom(
        pb.DisplayBrightness(configured: true, available: true, percent: 0),
      );

      expect(setting.percent, 0);
      expect(setting.isUsable, isTrue);
    });
  });
}
