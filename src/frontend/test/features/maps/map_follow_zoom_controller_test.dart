import 'dart:async';

import 'package:carnine_frontend/features/maps/presentation/map_follow_zoom_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_map/local_map.dart';

import '../../fakes/fake_map_follow_zoom_store.dart';

MapFollowZoomController _controller(FakeMapFollowZoomStore? store) {
  final controller = MapFollowZoomController(store: store);
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  test('without anything saved the map follows at 16', () async {
    final controller = _controller(FakeMapFollowZoomStore());

    await controller.load();

    expect(controller.zoom, 16);
    expect(controller.zoom, MapFollowZoomController.defaultZoom);
  });

  test('a saved level is the one that counts', () async {
    final controller = _controller(FakeMapFollowZoomStore(zoom: 15));

    await controller.load();

    expect(controller.zoom, 15);
    expect(controller.shownZoom, 15);
  });

  test('a level outside the slider is kept as it is', () async {
    final controller = _controller(FakeMapFollowZoomStore(zoom: 12));

    await controller.load();

    expect(controller.zoom, 12);
  });

  test('without a backend it stays at 16 and takes a change', () async {
    final controller = _controller(null);
    await controller.load();

    await controller.commit(14);

    expect(controller.zoom, 14);
  });

  group('choosing a level', () {
    test('shows what is dragged at once and does not send it', () async {
      final store = FakeMapFollowZoomStore();
      final controller = _controller(store);
      await controller.load();

      controller
        ..drag(15)
        ..drag(14);

      expect(controller.shownZoom, 14);
      expect(controller.zoom, 16, reason: 'the map stays until it is let go');
      expect(store.saves, isEmpty);
    });

    test('is saved when the thumb is let go, and the map goes there', () async {
      final store = FakeMapFollowZoomStore();
      final controller = _controller(store);
      await controller.load();
      var notified = 0;
      controller.addListener(() => notified++);

      controller.drag(17);
      await controller.commit(17);

      expect(store.saves, [17]);
      expect(controller.zoom, 17);
      expect(controller.shownZoom, 17);
      expect(notified, greaterThan(0));
    });

    test('the same level again is not saved again', () async {
      final store = FakeMapFollowZoomStore();
      final controller = _controller(store);
      await controller.load();

      await controller.commit(16);

      expect(store.saves, isEmpty);
    });

    test('a save that fails puts the map back and says so', () async {
      final store = FakeMapFollowZoomStore(zoom: 16);
      final controller = _controller(store);
      await controller.load();
      store.saveError = StateError('no');

      await controller.commit(14);

      expect(controller.zoom, 16);
      expect(controller.shownZoom, 16);
      expect(controller.errorKey, AppTextKey.mediaCommandFailed);
    });

    test('the message goes away by itself', () {
      fakeAsync((async) {
        final store = FakeMapFollowZoomStore();
        final controller = MapFollowZoomController(store: store);
        controller.load();
        async.flushMicrotasks();
        store.saveError = StateError('no');

        controller.commit(14);
        async.flushMicrotasks();
        expect(controller.errorKey, isNotNull);

        async.elapse(const Duration(seconds: 5));
        expect(controller.errorKey, isNull);
        controller.dispose();
      });
    });
  });

  group('the backend is not up yet', () {
    test('it asks again with growing pauses, then has the level', () {
      fakeAsync((async) {
        final store = FakeMapFollowZoomStore(zoom: 15)
          ..loadError = StateError('down');
        final controller = MapFollowZoomController(store: store);

        controller.load();
        async.flushMicrotasks();
        expect(store.loads, 1);
        expect(controller.zoom, 16);

        async.elapse(const Duration(seconds: 1));
        expect(store.loads, 2);
        async.elapse(const Duration(seconds: 1, milliseconds: 900));
        expect(store.loads, 2);
        async.elapse(const Duration(milliseconds: 100));
        expect(store.loads, 3);

        store.loadError = null;
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(controller.zoom, 15);
        controller.dispose();
      });
    });

    test('after the last pause it gives up and leaves 16', () {
      fakeAsync((async) {
        final store = FakeMapFollowZoomStore()..loadError = StateError('down');
        final controller = MapFollowZoomController(store: store);

        controller.load();
        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();

        // The first try and one for each pause: 1 + 5.
        expect(store.loads, 6);
        expect(controller.zoom, 16);
        controller.dispose();
      });
    });

    test('a level the user chose meanwhile is not overwritten', () {
      fakeAsync((async) {
        final store = FakeMapFollowZoomStore(zoom: 17)
          ..loadGate = Completer<void>();
        final controller = MapFollowZoomController(store: store);

        controller.load();
        async.flushMicrotasks();
        controller.commit(14);
        async.flushMicrotasks();
        store.loadGate?.complete();
        async.flushMicrotasks();

        expect(controller.zoom, 14);
        controller.dispose();
      });
    });
  });

  group('the map config', () {
    final base = MapConfig(minZoom: 8, maxZoom: 17, followZoom: 16);

    test('carries the level to follow at', () async {
      final controller = _controller(FakeMapFollowZoomStore(zoom: 15));
      await controller.load();

      expect(controller.configFor(base).followZoom, 15);
      expect(controller.configFor(base).minZoom, 8, reason: 'the rest stays');
    });

    test('is the same object while nothing changes, so the map does not '
        'zoom again', () async {
      final controller = _controller(FakeMapFollowZoomStore());
      await controller.load();

      final first = controller.configFor(base);
      controller.drag(14);
      final second = controller.configFor(base);

      expect(identical(first, second), isTrue);
    });

    test('is a new object when the level changes', () async {
      final controller = _controller(FakeMapFollowZoomStore());
      await controller.load();
      final first = controller.configFor(base);

      await controller.commit(14);
      final second = controller.configFor(base);

      expect(identical(first, second), isFalse);
      expect(second.followZoom, 14);
    });
  });
}
