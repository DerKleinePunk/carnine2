import 'dart:async';

import 'package:carnine_frontend/data/services/carnine_grpc_service.dart';
import 'package:carnine_frontend/features/settings/data/install_values_store.dart';
import 'package:carnine_frontend/features/settings/presentation/install_values_controller.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart' as pb;
import 'package:fake_async/fake_async.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

import '../../fakes/fake_install_values_store.dart';

InstallValuesController _controller(FakeInstallValuesStore store) {
  final controller = InstallValuesController(store: store, password: '4321');
  addTearDown(controller.dispose);
  return controller;
}

InstallValue _value(InstallValuesController controller, String key) =>
    controller.values.settings.firstWhere((value) => value.key == key);

void main() {
  group('what the backend lists (#207)', () {
    test('the values in the groups and order the backend gives', () async {
      final controller = _controller(FakeInstallValuesStore());
      expect(controller.status, InstallValuesStatus.loading);

      await controller.load();

      expect(controller.status, InstallValuesStatus.ready);
      expect(
        [for (final (group, _) in controller.groups) group],
        ['Rückwärtsgang', 'Tonausgabe', 'Netzteil'],
      );
      expect(controller.groups.first.$2.map((value) => value.key).toList(), [
        'reverse_gear.source',
        'reverse_gear.gpio_line',
        'reverse_gear.active_low',
        'reverse_gear.gpio_chip',
      ]);
    });

    test('a backend that is away is offline; trying again works', () async {
      final store = FakeInstallValuesStore()
        ..loadError = const InstallValuesException(
          InstallValuesFailure.unreachable,
        );
      final controller = _controller(store);

      await controller.load();
      expect(controller.status, InstallValuesStatus.offline);

      store.loadError = null;
      await controller.load();
      expect(controller.status, InstallValuesStatus.ready);
    });
  });

  group('changes', () {
    test('collect on the page and show at once', () async {
      final controller = _controller(FakeInstallValuesStore());
      await controller.load();
      final line = _value(controller, 'reverse_gear.gpio_line');

      controller.change(line, '26');

      expect(controller.hasChanges, isTrue);
      expect(controller.changeCount, 1);
      expect(controller.isChanged(line.key), isTrue);
      expect(controller.shownValue(line), '26');
    });

    test('back to what the files say is no change', () async {
      final controller = _controller(FakeInstallValuesStore());
      await controller.load();
      final rear = _value(controller, 'audio.rear_percent');

      controller.change(rear, '40');
      controller.change(rear, '30');

      expect(controller.hasChanges, isFalse);
    });

    test('a reset shows the default and counts as a change', () async {
      final controller = _controller(FakeInstallValuesStore());
      await controller.load();
      final rear = _value(controller, 'audio.rear_percent');

      controller.reset(rear);

      expect(controller.isResetPending(rear.key), isTrue);
      expect(controller.shownValue(rear), '100');
      expect(controller.changeCount, 1);
    });

    test('resetting a value no file sets only drops its change', () async {
      final controller = _controller(FakeInstallValuesStore());
      await controller.load();
      final line = _value(controller, 'reverse_gear.gpio_line');

      controller.change(line, '26');
      controller.reset(line);

      expect(controller.hasChanges, isFalse);
    });

    test('Verwerfen drops them all', () async {
      final controller = _controller(FakeInstallValuesStore());
      await controller.load();
      controller.change(_value(controller, 'reverse_gear.gpio_line'), '26');
      controller.change(_value(controller, 'power_supply.enabled'), 'true');

      controller.discard();

      expect(controller.hasChanges, isFalse);
    });
  });

  group('saving', () {
    test(
      'sends only the changed keys, with the password, in one call',
      () async {
        final store = FakeInstallValuesStore();
        final controller = _controller(store);
        await controller.load();
        controller.change(_value(controller, 'reverse_gear.source'), 'gpio');
        controller.change(_value(controller, 'reverse_gear.gpio_line'), '26');
        controller.reset(_value(controller, 'audio.rear_percent'));

        final outcome = await controller.save();

        expect(outcome, InstallSaveOutcome.saved);
        expect(store.saves, hasLength(1));
        final saved = store.saves.single;
        expect(saved.password, '4321');
        expect(
          [
            for (final change in saved.changes)
              change.reset
                  ? '${change.key}=reset'
                  : '${change.key}=${change.value}',
          ],
          [
            'reverse_gear.source=gpio',
            'reverse_gear.gpio_line=26',
            'audio.rear_percent=reset',
          ],
        );
      },
    );

    test('afterwards the page shows what the backend answered', () async {
      final store = FakeInstallValuesStore();
      final controller = _controller(store);
      await controller.load();
      controller.change(_value(controller, 'reverse_gear.gpio_line'), '26');

      await controller.save();

      expect(controller.hasChanges, isFalse);
      final line = _value(controller, 'reverse_gear.gpio_line');
      expect(line.value, '26');
      expect(line.origin, endsWith('99-ui.toml'));
      expect(controller.values.restartRequired, isTrue);
    });

    test('"Gespeichert" goes away by itself', () {
      fakeAsync((async) {
        final controller = InstallValuesController(
          store: FakeInstallValuesStore(),
          password: '4321',
        );
        controller.load();
        async.flushMicrotasks();
        controller.change(
          controller.values.settings.firstWhere(
            (value) => value.key == 'power_supply.enabled',
          ),
          'true',
        );
        controller.save();
        async.flushMicrotasks();
        expect(controller.outcome, InstallSaveOutcome.saved);

        async.elapse(const Duration(seconds: 5));
        expect(controller.outcome, isNull);
        controller.dispose();
      });
    });

    test('a refused value keeps the changes and gives the reason', () async {
      final store = FakeInstallValuesStore()
        ..saveError = const InstallValuesException(
          InstallValuesFailure.rejected,
          'Konfiguration ungültig: reverse_gear.gpio_line is required',
        );
      final controller = _controller(store);
      await controller.load();
      controller.change(_value(controller, 'reverse_gear.source'), 'gpio');

      final outcome = await controller.save();

      expect(outcome, InstallSaveOutcome.rejected);
      expect(controller.rejection, contains('gpio_line is required'));
      expect(controller.hasChanges, isTrue);
      expect(_value(controller, 'reverse_gear.source').value, 'none');
    });

    test('a wrong password, then the new one', () async {
      final store = FakeInstallValuesStore(password: 'neu1');
      final controller = _controller(store);
      await controller.load();
      controller.change(_value(controller, 'power_supply.enabled'), 'true');

      expect(await controller.save(), InstallSaveOutcome.wrongPassword);
      expect(controller.hasChanges, isTrue);

      controller.updatePassword('neu1');
      expect(await controller.save(), InstallSaveOutcome.saved);
      expect(store.saves.last.password, 'neu1');
    });

    test('a backend that is away saves nothing', () async {
      final store = FakeInstallValuesStore()
        ..saveError = const InstallValuesException(
          InstallValuesFailure.unreachable,
        );
      final controller = _controller(store);
      await controller.load();
      controller.change(_value(controller, 'power_supply.enabled'), 'true');

      expect(await controller.save(), InstallSaveOutcome.unreachable);
      expect(controller.hasChanges, isTrue);
    });

    test('while it saves, a second save sends nothing', () async {
      final store = FakeInstallValuesStore()..saveGate = Completer<void>();
      final controller = _controller(store);
      await controller.load();
      controller.change(_value(controller, 'power_supply.enabled'), 'true');

      final first = controller.save();
      expect(controller.isSaving, isTrue);
      unawaited(controller.save());
      store.saveGate?.complete();
      await first;

      expect(store.saves, hasLength(1));
    });
  });

  group('from the backend', () {
    test('every field arrives as it is', () {
      final values = CarnineGrpcService.installValuesFrom(
        pb.InstallSettings(
          settings: [
            pb.InstallSetting(
              key: 'audio.rear_percent',
              group: 'Tonausgabe',
              label: 'Pegel hinten',
              help: 'Hilfe',
              kind: pb.InstallSettingKind.INSTALL_SETTING_KIND_INTEGER,
              min: Int64(0),
              max: Int64(100),
              unit: '%',
              defaultValue: '100',
              optional: true,
              value: '30',
              origin: '/etc/carnine/config.d/99-ui.toml',
              restartPending: true,
            ),
            pb.InstallSetting(
              key: 'audio.output_card',
              kind: pb.InstallSettingKind.INSTALL_SETTING_KIND_SOUND_CARD,
              choices: [
                pb.InstallSettingChoice(value: 'vc4hdmi0', label: 'HDMI 0'),
              ],
            ),
            pb.InstallSetting(
              key: 'x.y',
              kind: pb.InstallSettingKind.INSTALL_SETTING_KIND_UNSPECIFIED,
            ),
          ],
          restartRequired: true,
          uiDropInError: 'invalid',
          uiDropInPath: '/etc/carnine/config.d/99-ui.toml',
        ),
      );

      final rear = values.settings[0];
      expect(rear.kind, InstallValueKind.integer);
      expect([rear.min, rear.max, rear.unit], [0, 100, '%']);
      expect([rear.value, rear.defaultValue], ['30', '100']);
      expect(rear.optional, isTrue);
      expect(rear.isDefault, isFalse);
      expect(rear.restartPending, isTrue);
      expect(values.settings[1].kind, InstallValueKind.soundCard);
      expect(values.settings[1].choices.single.label, 'HDMI 0');
      expect(values.settings[1].isDefault, isTrue);
      expect(values.settings[2].kind, InstallValueKind.unknown);
      expect(values.restartRequired, isTrue);
      expect(values.uiDropInError, 'invalid');
    });

    test('the status codes mean what the ticket says', () {
      InstallValuesFailure failureOf(int code) =>
          CarnineGrpcService.installValuesExceptionFrom(
            GrpcError.custom(code, 'm'),
          ).failure;

      expect(
        failureOf(StatusCode.permissionDenied),
        InstallValuesFailure.wrongPassword,
      );
      expect(
        failureOf(StatusCode.invalidArgument),
        InstallValuesFailure.rejected,
      );
      expect(
        failureOf(StatusCode.unavailable),
        InstallValuesFailure.unreachable,
      );
      expect(failureOf(StatusCode.internal), InstallValuesFailure.failed);
      expect(
        CarnineGrpcService.installValuesExceptionFrom(
          GrpcError.invalidArgument('Konfiguration ungültig: x'),
        ).message,
        'Konfiguration ungültig: x',
      );
    });
  });
}
