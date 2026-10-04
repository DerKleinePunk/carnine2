import 'package:carnine_frontend/features/controls/data/controls_repository.dart';
import 'package:carnine_frontend/features/controls/domain/control.dart';
import 'package:carnine_frontend/features/controls/presentation/controls_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart' as pb;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_controls_repository.dart';

const _light = ControlDefinition(
  id: 'light',
  name: 'Innenlicht',
  kind: ControlKind.toggle,
);
const _fan = ControlDefinition(
  id: 'fan',
  name: 'Lüfter',
  kind: ControlKind.slider,
);

FakeControlsRepository _repository() => FakeControlsRepository(
  controls: const [_light, _fan],
  values: const {
    'light': ControlValue(id: 'light', isAvailable: true, isOn: false),
    'fan': ControlValue(id: 'fan', isAvailable: true, level: 20),
  },
);

void main() {
  test('loads the controls and the states from the stream', () async {
    final repository = _repository();
    final controller = ControlsController(repository: repository);
    addTearDown(controller.dispose);

    await controller.start();
    await pumpEventQueue();

    expect(controller.status, ControlsStatus.ready);
    expect(controller.controls.map((c) => c.id), ['light', 'fan']);
    expect(controller.isAvailable('light'), isTrue);
    expect(controller.isOn('light'), isFalse);
    expect(controller.levelOf(_fan), 20);
  });

  test('no controls set up is ready with an empty list', () async {
    final controller = ControlsController(repository: FakeControlsRepository());
    addTearDown(controller.dispose);

    await controller.start();

    expect(controller.status, ControlsStatus.ready);
    expect(controller.controls, isEmpty);
  });

  test('a control is not available before its state has come', () async {
    final repository = FakeControlsRepository(controls: const [_light]);
    final controller = ControlsController(repository: repository);
    addTearDown(controller.dispose);

    await controller.start();

    expect(controller.isAvailable('light'), isFalse);

    repository.push(
      const ControlValue(id: 'light', isAvailable: true, isOn: true),
    );
    await pumpEventQueue();

    expect(controller.isAvailable('light'), isTrue);
    expect(controller.isOn('light'), isTrue);
  });

  test('a change from elsewhere shows up, and a module that went away '
      'is not available', () async {
    final repository = _repository();
    final controller = ControlsController(repository: repository);
    addTearDown(controller.dispose);
    await controller.start();
    await pumpEventQueue();

    repository.push(
      const ControlValue(id: 'light', isAvailable: true, isOn: true),
    );
    await pumpEventQueue();
    expect(controller.isOn('light'), isTrue);

    repository.push(const ControlValue(id: 'light', isAvailable: false));
    await pumpEventQueue();
    expect(controller.isAvailable('light'), isFalse);
  });

  test('toggle sends the opposite of what the control shows', () async {
    final repository = _repository();
    final controller = ControlsController(repository: repository);
    addTearDown(controller.dispose);
    await controller.start();
    await pumpEventQueue();

    await controller.toggle('light');
    expect(controller.isOn('light'), isTrue);
    await controller.toggle('light');

    expect(repository.sets, ['light:on', 'light:off']);
    expect(controller.isOn('light'), isFalse);
  });

  test('a control that is not available cannot be toggled', () async {
    final repository = _repository();
    final controller = ControlsController(repository: repository);
    addTearDown(controller.dispose);
    await controller.start();
    repository.push(const ControlValue(id: 'light', isAvailable: false));
    await pumpEventQueue();

    await controller.toggle('light');

    expect(repository.sets, isEmpty);
  });

  test('a change that fails shows a message, and the state stays', () async {
    final repository = _repository();
    final controller = ControlsController(repository: repository);
    addTearDown(controller.dispose);
    await controller.start();
    await pumpEventQueue();
    repository.setError = StateError('module away');

    await controller.toggle('light');

    expect(controller.errorKey, AppTextKey.mediaCommandFailed);
    expect(controller.isOn('light'), isFalse);

    controller.dismissError();
    expect(controller.errorKey, isNull);
  });

  test('the error message goes by itself', () {
    fakeAsync((async) {
      final repository = _repository();
      final controller = ControlsController(repository: repository);
      controller.start();
      async.flushMicrotasks();
      repository.setError = StateError('module away');

      controller.toggle('light');
      async.flushMicrotasks();
      expect(controller.errorKey, isNotNull);

      async.elapse(const Duration(seconds: 5));
      expect(controller.errorKey, isNull);
      controller.dispose();
    });
  });

  group('a slider', () {
    test('shows the dragged value at once and sends it throttled', () {
      fakeAsync((async) {
        final repository = _repository();
        final controller = ControlsController(repository: repository);
        controller.start();
        async.flushMicrotasks();

        controller.dragLevel('fan', 30);
        expect(controller.levelOf(_fan), 30);
        controller.dragLevel('fan', 40);
        controller.dragLevel('fan', 50);
        // Nothing yet: a drag does not send every step.
        expect(repository.sets, isEmpty);

        async.elapse(const Duration(milliseconds: 150));
        async.flushMicrotasks();
        expect(repository.sets, ['fan:level:50']);

        controller.dragLevel('fan', 60);
        controller.dragLevel('fan', 70);
        async.elapse(const Duration(milliseconds: 150));
        async.flushMicrotasks();
        expect(repository.sets, ['fan:level:50', 'fan:level:70']);
        controller.dispose();
      });
    });

    test('is sent for good when it is let go', () async {
      final repository = _repository();
      final controller = ControlsController(repository: repository);
      addTearDown(controller.dispose);
      await controller.start();
      await pumpEventQueue();

      controller.dragLevel('fan', 80);
      await controller.commitLevel('fan', 90);

      expect(repository.sets, ['fan:level:90']);
      expect(controller.levelOf(_fan), 90);
    });

    test('does not jump back while it is dragged', () async {
      final repository = _repository();
      final controller = ControlsController(repository: repository);
      addTearDown(controller.dispose);
      await controller.start();
      await pumpEventQueue();

      controller.dragLevel('fan', 75);
      repository.push(
        const ControlValue(id: 'fan', isAvailable: true, level: 10),
      );
      await pumpEventQueue();

      expect(controller.levelOf(_fan), 75);
    });

    test('a value sent twice in a row is not sent again by the throttle', () {
      fakeAsync((async) {
        final repository = _repository();
        final controller = ControlsController(repository: repository);
        controller.start();
        async.flushMicrotasks();

        controller.dragLevel('fan', 40);
        async.elapse(const Duration(milliseconds: 150));
        async.flushMicrotasks();
        controller.dragLevel('fan', 40);
        async.elapse(const Duration(milliseconds: 150));
        async.flushMicrotasks();

        expect(repository.sets, ['fan:level:40']);
        controller.dispose();
      });
    });
  });

  group('the backend is away', () {
    test(
      'a failing load goes offline, then tries again with growing pauses',
      () {
        fakeAsync((async) {
          final repository = _repository()..loadError = StateError('down');
          final controller = ControlsController(repository: repository);

          controller.start();
          async.flushMicrotasks();
          expect(controller.status, ControlsStatus.offline);
          expect(repository.loads, 1);

          async.elapse(const Duration(milliseconds: 500));
          async.flushMicrotasks();
          expect(repository.loads, 2);
          // The next pause is longer: one second.
          async.elapse(const Duration(milliseconds: 900));
          async.flushMicrotasks();
          expect(repository.loads, 2);
          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();
          expect(repository.loads, 3);

          repository.loadError = null;
          async.elapse(const Duration(seconds: 3));
          async.flushMicrotasks();
          expect(controller.status, ControlsStatus.ready);
          controller.dispose();
        });
      },
    );

    test('a broken stream goes offline and comes back with fresh controls', () {
      fakeAsync((async) {
        final repository = _repository();
        final controller = ControlsController(repository: repository);
        controller.start();
        async.flushMicrotasks();
        expect(controller.status, ControlsStatus.ready);

        repository.breakStream();
        async.flushMicrotasks();
        expect(controller.status, ControlsStatus.offline);

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(controller.status, ControlsStatus.ready);
        expect(repository.loads, 2);
        expect(repository.streamStarts, 2);
        controller.dispose();
      });
    });

    test('a stream the backend closes counts as lost', () {
      fakeAsync((async) {
        final repository = _repository();
        final controller = ControlsController(repository: repository);
        controller.start();
        async.flushMicrotasks();

        repository.closeStream();
        async.flushMicrotasks();

        expect(controller.status, ControlsStatus.offline);
        controller.dispose();
      });
    });

    test('retryNow tries at once', () {
      fakeAsync((async) {
        final repository = _repository()..loadError = StateError('down');
        final controller = ControlsController(repository: repository);
        controller.start();
        async.flushMicrotasks();
        repository.loadError = null;

        controller.retryNow();
        async.flushMicrotasks();

        expect(controller.status, ControlsStatus.ready);
        controller.dispose();
      });
    });
  });

  group('mapping from the backend', () {
    test(
      'a switch and a slider become controls, an unknown kind is left out',
      () {
        final switchControl = controlDefinitionFrom(
          pb.Control(
            id: 'a',
            name: 'Innenlicht',
            type: pb.ControlType.CONTROL_TYPE_SWITCH,
          ),
        );
        final slider = controlDefinitionFrom(
          pb.Control(
            id: 'b',
            name: 'Lüfter',
            type: pb.ControlType.CONTROL_TYPE_SLIDER,
            min: 10,
            max: 90,
          ),
        );
        final unknown = controlDefinitionFrom(
          pb.Control(
            id: 'c',
            name: 'x',
            type: pb.ControlType.CONTROL_TYPE_UNSPECIFIED,
          ),
        );

        expect(switchControl?.kind, ControlKind.toggle);
        expect(switchControl?.name, 'Innenlicht');
        expect(slider?.kind, ControlKind.slider);
        expect((slider?.min, slider?.max), (10, 90));
        expect(unknown, isNull);
      },
    );

    test('a slider without a usable range gets 0 to 100', () {
      final slider = controlDefinitionFrom(
        pb.Control(
          id: 'b',
          name: 'Lüfter',
          type: pb.ControlType.CONTROL_TYPE_SLIDER,
        ),
      );

      expect((slider?.min, slider?.max), (0, 100));
    });

    test('a state carries its value by kind', () {
      final on = controlValueFrom(
        pb.ControlState(id: 'a', on: true, available: true),
      );
      final level = controlValueFrom(
        pb.ControlState(id: 'b', level: 70, available: true),
      );
      final away = controlValueFrom(pb.ControlState(id: 'c', available: false));

      expect((on.isOn, on.level, on.isAvailable), (true, null, true));
      expect((level.isOn, level.level), (null, 70));
      expect(away.isAvailable, isFalse);
      expect((away.isOn, away.level), (null, null));
    });

    test('off is a value, not "unset"', () {
      final off = controlValueFrom(
        pb.ControlState(id: 'a', on: false, available: true),
      );

      expect(off.isOn, isFalse);
    });
  });
}
