import 'dart:async';

import 'package:carnine_frontend/features/maps/data/traffic_setting_store.dart';
import 'package:carnine_frontend/features/maps/presentation/traffic_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stand-in for the backend's `UiState.traffic_enabled`.
class _FakeStore implements TrafficSettingStore {
  bool saved = false;
  int failLoads = 0;
  bool failSave = false;
  Completer<void>? holdLoad;
  final saves = <bool>[];

  @override
  Future<bool> loadTrafficEnabled() async {
    // What the backend had when it was asked, even if the answer is late.
    final answer = saved;
    await holdLoad?.future;
    if (failLoads > 0) {
      failLoads--;
      throw StateError('backend not up yet');
    }
    return answer;
  }

  @override
  Future<void> saveTrafficEnabled(bool enabled) async {
    saves.add(enabled);
    if (failSave) {
      throw StateError('save failed');
    }
    saved = enabled;
  }
}

void main() {
  late _FakeStore store;
  late List<bool> applied;
  late TrafficController controller;

  TrafficController create({TrafficSettingStore? withStore}) =>
      TrafficController(
        store: withStore,
        apply: applied.add,
        loadRetryDelays: const [Duration.zero, Duration.zero],
      );

  setUp(() {
    store = _FakeStore();
    applied = [];
    controller = create(withStore: store);
  });

  tearDown(() => controller.dispose());

  test(
    'traffic is off before anything is loaded, and the map hears nothing',
    () {
      expect(controller.enabled, isFalse);
      expect(applied, isEmpty);
    },
  );

  test('without a store it stays off', () async {
    final noStore = create();
    await noStore.load();
    expect(noStore.enabled, isFalse);
    expect(applied, isEmpty);
    noStore.dispose();
  });

  test('a saved "on" turns the map on', () async {
    store.saved = true;
    await controller.load();
    expect(controller.enabled, isTrue);
    expect(applied, [true]);
  });

  test('a saved "off" leaves the map alone', () async {
    await controller.load();
    expect(controller.enabled, isFalse);
    expect(applied, isEmpty);
  });

  test('while the backend is not up yet it asks again', () async {
    store
      ..saved = true
      ..failLoads = 2;
    await controller.load();
    expect(controller.enabled, isTrue);
    expect(applied, [true]);
  });

  test('when the backend never answers, traffic stays off', () async {
    store
      ..saved = true
      ..failLoads = 10;
    await controller.load();
    expect(controller.enabled, isFalse);
    expect(applied, isEmpty);
  });

  test('switching on reaches the map at once and is saved', () async {
    await controller.setEnabled(true);
    expect(controller.enabled, isTrue);
    expect(applied, [true]);
    expect(store.saves, [true]);

    await controller.setEnabled(false);
    expect(controller.enabled, isFalse);
    expect(applied, [true, false]);
    expect(store.saves, [true, false]);
  });

  test('the same state again is neither applied nor saved', () async {
    await controller.setEnabled(false);
    expect(applied, isEmpty);
    expect(store.saves, isEmpty);
  });

  test('when saving fails, the switch and the map go back', () async {
    store.failSave = true;
    await controller.setEnabled(true);
    expect(controller.enabled, isFalse);
    expect(applied, [true, false]);
    expect(controller.errorKey, isNotNull);
  });

  test('a load that answers late does not undo the user\'s choice', () async {
    store
      ..saved = false
      ..holdLoad = Completer<void>();
    final loading = controller.load();
    await controller.setEnabled(true);
    store.holdLoad!.complete();
    await loading;
    expect(controller.enabled, isTrue);
    expect(applied, [true]);
  });
}
