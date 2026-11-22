import 'dart:async';

import 'package:carnine_frontend/features/dashboard/data/reverse_gear_source.dart';
import 'package:carnine_frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
import 'package:carnine_frontend/features/dashboard/presentation/reverse_gear_controller.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart' as pb;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dashboard_page_restore_test.dart' show FakeUiStateStore;

class FakeReverseGearSource implements ReverseGearSource {
  final StreamController<ReverseGearStatus> controller =
      StreamController<ReverseGearStatus>.broadcast();

  @override
  Stream<ReverseGearStatus> get statuses => controller.stream;

  @override
  Future<void> dispose() => controller.close();
}

const ReverseGearStatus gearIn = ReverseGearStatus(
  configured: true,
  gear: ReverseGear.engaged,
);
const ReverseGearStatus gearOut = ReverseGearStatus(
  configured: true,
  gear: ReverseGear.out,
);
const ReverseGearStatus gearUnknown = ReverseGearStatus(
  configured: true,
  gear: ReverseGear.unknown,
);

/// The controller with a page of its own instead of the dashboard: [page]
/// is what is open, [shown] what the controller switched to.
class _Rig {
  _Rig({this.page = DashboardDestination.maps}) {
    controller = ReverseGearController(
      currentPage: () => page,
      showCamera: () {
        page = DashboardDestination.camera;
        shown.add(DashboardDestination.camera);
      },
      showPage: (destination) {
        page = destination;
        shown.add(destination);
      },
      source: source,
    )..start();
  }

  DashboardDestination page;
  final List<DashboardDestination> shown = [];
  final FakeReverseGearSource source = FakeReverseGearSource();
  late final ReverseGearController controller;

  Future<void> send(ReverseGearStatus status) async {
    source.controller.add(status);
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('what the backend says (#191)', () {
    test('in, out and unknown arrive as such', () {
      ReverseGear gearOf(pb.ReverseGear gear) => reverseGearStatusFromProto(
        pb.ReverseGearStatus(configured: true, gear: gear),
      ).gear;

      expect(gearOf(pb.ReverseGear.REVERSE_GEAR_IN), ReverseGear.engaged);
      expect(gearOf(pb.ReverseGear.REVERSE_GEAR_OUT), ReverseGear.out);
      expect(gearOf(pb.ReverseGear.REVERSE_GEAR_UNKNOWN), ReverseGear.unknown);
      expect(
        gearOf(pb.ReverseGear.REVERSE_GEAR_UNSPECIFIED),
        ReverseGear.unknown,
        reason: 'never taken for out',
      );
    });

    test('without a source it is not configured, whatever the gear says', () {
      final status = reverseGearStatusFromProto(
        pb.ReverseGearStatus(gear: pb.ReverseGear.REVERSE_GEAR_IN),
      );

      expect(status.configured, isFalse);
      expect(status.gear, ReverseGear.unknown);
    });
  });

  group('the camera while the gear is in', () {
    test('in brings the camera, out the page from before', () async {
      final rig = _Rig();
      addTearDown(rig.controller.dispose);

      await rig.send(gearIn);
      expect(rig.shown, [DashboardDestination.camera]);
      expect(rig.controller.isEngaged, isTrue);

      await rig.send(gearOut);
      expect(rig.shown, [
        DashboardDestination.camera,
        DashboardDestination.maps,
      ]);
      expect(rig.controller.isEngaged, isFalse);
    });

    test('a gear in at the start brings the camera at once', () async {
      final rig = _Rig(page: DashboardDestination.home);
      addTearDown(rig.controller.dispose);

      await rig.send(gearIn);

      expect(rig.page, DashboardDestination.camera);
    });

    test('in again while it is in changes nothing', () async {
      final rig = _Rig();
      addTearDown(rig.controller.dispose);

      await rig.send(gearIn);
      await rig.send(gearIn);

      expect(rig.shown, [DashboardDestination.camera]);
    });

    test('unknown switches nothing, not even back', () async {
      final rig = _Rig();
      addTearDown(rig.controller.dispose);

      await rig.send(gearUnknown);
      expect(rig.shown, isEmpty);

      await rig.send(gearIn);
      await rig.send(gearUnknown);
      expect(rig.page, DashboardDestination.camera, reason: 'stays');

      // The page from before is still known when the gear is out again.
      await rig.send(gearOut);
      expect(rig.page, DashboardDestination.maps);
    });

    test('a page the driver chose while reversing stays', () async {
      final rig = _Rig();
      addTearDown(rig.controller.dispose);

      await rig.send(gearIn);
      rig.page = DashboardDestination.media;
      await rig.send(gearOut);

      expect(rig.page, DashboardDestination.media);
      expect(rig.shown, [DashboardDestination.camera]);
    });

    test(
      'with the camera already open there is nothing to go back to',
      () async {
        final rig = _Rig(page: DashboardDestination.camera);
        addTearDown(rig.controller.dispose);

        await rig.send(gearIn);
        await rig.send(gearOut);

        expect(rig.shown, isEmpty);
        expect(rig.page, DashboardDestination.camera);
      },
    );

    test('out without an in before changes nothing', () async {
      final rig = _Rig();
      addTearDown(rig.controller.dispose);

      await rig.send(gearOut);

      expect(rig.shown, isEmpty);
    });

    test('without a source nothing happens at all', () async {
      final rig = _Rig();
      addTearDown(rig.controller.dispose);

      await rig.send(
        const ReverseGearStatus(configured: false, gear: ReverseGear.engaged),
      );

      expect(rig.shown, isEmpty);
      expect(rig.controller.isEngaged, isFalse);
      expect(rig.controller.isSignalMissing, isFalse);
    });
  });

  group('the hint that the signal is missing', () {
    test('only while a source cannot tell the gear', () async {
      final rig = _Rig();
      addTearDown(rig.controller.dispose);
      expect(rig.controller.signalMissing.value, isFalse);

      await rig.send(gearUnknown);
      expect(rig.controller.signalMissing.value, isTrue);

      await rig.send(gearIn);
      expect(rig.controller.signalMissing.value, isFalse);

      await rig.send(ReverseGearStatus.none);
      expect(rig.controller.signalMissing.value, isFalse);
    });
  });

  group('the dashboard does not keep the camera as the last page', () {
    test('a page shown without saving is not saved', () {
      fakeAsync((async) {
        final store = FakeUiStateStore();
        final dashboard = DashboardController(uiStateStore: store);

        dashboard.showWithoutSaving(DashboardDestination.camera);
        async.elapse(const Duration(seconds: 5));

        expect(dashboard.selectedItem.destination, DashboardDestination.camera);
        expect(store.saved, isEmpty);

        dashboard.showWithoutSaving(DashboardDestination.home);
        async.elapse(const Duration(seconds: 5));
        dashboard.dispose();
        async.flushMicrotasks();
        expect(store.saved, isEmpty, reason: 'not even on dispose');
      });
    });

    test('a tap before the gear is still saved', () {
      fakeAsync((async) {
        final store = FakeUiStateStore();
        final dashboard = DashboardController(uiStateStore: store);

        dashboard.selectDestination(DashboardDestination.media);
        dashboard.showWithoutSaving(DashboardDestination.camera);
        async.elapse(const Duration(seconds: 5));

        expect(store.saved, ['media']);
        dashboard.dispose();
      });
    });

    test(
      'a gear in at start keeps the camera over the restored page',
      () async {
        final store = FakeUiStateStore(lastPage: 'maps')
          ..loadGate = Completer<void>();
        final dashboard = DashboardController(uiStateStore: store);
        addTearDown(dashboard.dispose);

        final restoring = dashboard.restoreLastPage();
        dashboard.showWithoutSaving(DashboardDestination.camera);
        store.loadGate?.complete();
        await restoring;

        expect(dashboard.selectedItem.destination, DashboardDestination.camera);
      },
    );
  });
}
