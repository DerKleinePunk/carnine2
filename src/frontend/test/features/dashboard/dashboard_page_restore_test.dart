import 'dart:async';

import 'package:carnine_frontend/features/dashboard/data/ui_state_store.dart';
import 'package:carnine_frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

class FakeUiStateStore implements UiStateStore {
  FakeUiStateStore({this.lastPage = ''});

  String lastPage;
  final List<String> saved = <String>[];
  Completer<void>? loadGate;

  /// Errors thrown by the next calls to [loadLastPage], one per call.
  final List<Object> loadErrors = <Object>[];
  int loadCalls = 0;

  String language = '';
  final List<String> savedLanguages = <String>[];

  @override
  Future<String> loadLanguage() async => language;

  @override
  Future<void> saveLanguage(String languageCode) async {
    savedLanguages.add(languageCode);
  }

  @override
  Future<String> loadLastPage() async {
    loadCalls++;
    await loadGate?.future;
    if (loadErrors.isNotEmpty) {
      throw loadErrors.removeAt(0);
    }
    return lastPage;
  }

  @override
  Future<void> saveLastPage(String page) async {
    saved.add(page);
    lastPage = page;
  }
}

int indexOf(DashboardDestination destination) => DashboardController.navItems
    .indexWhere((item) => item.destination == destination);

void main() {
  test('restores the page saved last', () async {
    final controller = DashboardController(
      uiStateStore: FakeUiStateStore(lastPage: 'maps'),
    );

    await controller.restoreLastPage();

    expect(controller.selectedItem.destination, DashboardDestination.maps);
  });

  test('a saved climate page opens the camera page that replaced it', () async {
    for (final name in ['climate', 'camera']) {
      final controller = DashboardController(
        uiStateStore: FakeUiStateStore(lastPage: name),
      );

      await controller.restoreLastPage();

      expect(
        controller.selectedItem.destination,
        DashboardDestination.camera,
        reason: name,
      );
    }
  });

  test('stays on the first page for unknown names and settings', () async {
    for (final name in ['', 'gone', 'settings']) {
      final controller = DashboardController(
        uiStateStore: FakeUiStateStore(lastPage: name),
      );

      await controller.restoreLastPage();

      expect(controller.selectedIndex, 0, reason: name);
    }
  });

  test('a page picked while loading wins over the saved one', () async {
    final store = FakeUiStateStore(lastPage: 'maps')
      ..loadGate = Completer<void>();
    final controller = DashboardController(uiStateStore: store);

    final restoring = controller.restoreLastPage();
    controller.selectItem(indexOf(DashboardDestination.media));
    store.loadGate?.complete();
    await restoring;

    expect(controller.selectedItem.destination, DashboardDestination.media);
  });

  test('retries while the backend is not up yet (#52)', () {
    fakeAsync((async) {
      final store = FakeUiStateStore(lastPage: 'media')
        ..loadErrors.addAll([
          const GrpcError.unavailable('connection refused'),
          const GrpcError.unavailable('connection refused'),
        ]);
      final controller = DashboardController(uiStateStore: store);

      unawaited(controller.restoreLastPage());
      async.elapse(const Duration(seconds: 1));

      expect(store.loadCalls, 3);
      expect(controller.selectedItem.destination, DashboardDestination.media);
    });
  });

  test('a page picked while the backend is down wins', () {
    fakeAsync((async) {
      final store = FakeUiStateStore(lastPage: 'maps')
        ..loadErrors.add(const GrpcError.unavailable('connection refused'));
      final controller = DashboardController(uiStateStore: store);

      unawaited(controller.restoreLastPage());
      async.flushMicrotasks();
      controller.selectItem(indexOf(DashboardDestination.media));
      async.elapse(const Duration(seconds: 5));

      expect(store.loadCalls, 1);
      expect(controller.selectedItem.destination, DashboardDestination.media);
    });
  });

  test('gives up after a while without a backend', () {
    fakeAsync((async) {
      final store = FakeUiStateStore(lastPage: 'maps')
        ..loadErrors.addAll(
          List.filled(1000, const GrpcError.unavailable('connection refused')),
        );
      final controller = DashboardController(uiStateStore: store);

      unawaited(controller.restoreLastPage());
      async.elapse(DashboardController.restoreGiveUpAfter * 2);
      final calls = store.loadCalls;
      async.elapse(const Duration(minutes: 5));

      expect(store.loadCalls, calls);
      expect(calls, lessThan(100));
      expect(controller.selectedIndex, 0);
    });
  });

  test('does not retry other errors', () {
    fakeAsync((async) {
      final store = FakeUiStateStore(lastPage: 'maps')
        ..loadErrors.add(const GrpcError.unimplemented('getUiState'));
      final controller = DashboardController(uiStateStore: store);

      unawaited(controller.restoreLastPage());
      async.elapse(const Duration(seconds: 10));

      expect(store.loadCalls, 1);
      expect(controller.selectedIndex, 0);
    });
  });

  test('stops retrying once disposed', () {
    fakeAsync((async) {
      final store = FakeUiStateStore(lastPage: 'maps')
        ..loadErrors.addAll(
          List.filled(10, const GrpcError.unavailable('connection refused')),
        );
      final controller = DashboardController(uiStateStore: store);

      unawaited(controller.restoreLastPage());
      async.flushMicrotasks();
      controller.dispose();
      async.elapse(const Duration(seconds: 10));

      expect(store.loadCalls, 1);
    });
  });

  test('saves only the page the user settles on, never settings', () {
    fakeAsync((async) {
      final store = FakeUiStateStore();
      final controller = DashboardController(uiStateStore: store);

      controller.selectItem(indexOf(DashboardDestination.media));
      async.elapse(const Duration(milliseconds: 500));
      controller.selectItem(indexOf(DashboardDestination.maps));
      async.elapse(DashboardController.pageSaveDelay);
      controller.selectItem(indexOf(DashboardDestination.settings));
      async.elapse(DashboardController.pageSaveDelay * 2);

      expect(store.saved, ['maps']);
    });
  });

  test('saves a pending page when disposed', () {
    fakeAsync((async) {
      final store = FakeUiStateStore();
      DashboardController(uiStateStore: store)
        ..selectItem(indexOf(DashboardDestination.media))
        ..dispose();
      async.flushMicrotasks();

      expect(store.saved, ['media']);
      expect(async.pendingTimers, isEmpty);
    });
  });
}
