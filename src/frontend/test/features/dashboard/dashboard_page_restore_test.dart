import 'dart:async';

import 'package:carnine_frontend/features/dashboard/data/ui_state_store.dart';
import 'package:carnine_frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeUiStateStore implements UiStateStore {
  FakeUiStateStore({this.lastPage = ''});

  String lastPage;
  final List<String> saved = <String>[];
  Completer<void>? loadGate;

  @override
  Future<String> loadLastPage() async {
    await loadGate?.future;
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
