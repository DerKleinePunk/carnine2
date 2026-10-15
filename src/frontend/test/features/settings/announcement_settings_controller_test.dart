import 'dart:async';

import 'package:carnine_frontend/data/services/carnine_grpc_service.dart';
import 'package:carnine_frontend/features/settings/data/announcement_settings_store.dart';
import 'package:carnine_frontend/features/settings/presentation/announcement_settings_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart' as pb;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_announcement_settings_store.dart';

AnnouncementSettingsController _controller(
  FakeAnnouncementSettingsStore store,
) {
  final controller = AnnouncementSettingsController(store: store);
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  test('loads the settings of the backend', () async {
    final store = FakeAnnouncementSettingsStore(
      settings: const AnnouncementSettings(
        available: true,
        enabled: false,
        volumePercent: 70,
        musicUnderPercent: 0,
      ),
    );
    final controller = _controller(store);
    expect(controller.status, AnnouncementSettingsStatus.loading);

    await controller.load();

    expect(controller.status, AnnouncementSettingsStatus.ready);
    expect(controller.isAvailable, isTrue);
    expect(controller.isEnabled, isFalse);
    expect(controller.volume, 70);
    expect(controller.musicUnder, 0);
  });

  test('a backend that is away is offline, and load tries again', () async {
    final store = FakeAnnouncementSettingsStore()
      ..loadError = StateError('down');
    final controller = _controller(store);

    await controller.load();
    expect(controller.status, AnnouncementSettingsStatus.offline);

    store.loadError = null;
    await controller.load();
    expect(controller.status, AnnouncementSettingsStatus.ready);
    expect(store.loads, 2);
  });

  group('the switch', () {
    test('is saved at once', () async {
      final store = FakeAnnouncementSettingsStore();
      final controller = _controller(store);
      await controller.load();

      await controller.setEnabled(enabled: false);

      expect(store.saves, ['enabled=false']);
      expect(controller.isEnabled, isFalse);
    });

    test('with the state it already has sends nothing', () async {
      final store = FakeAnnouncementSettingsStore();
      final controller = _controller(store);
      await controller.load();

      await controller.setEnabled(enabled: true);

      expect(store.saves, isEmpty);
    });
  });

  group('a slider', () {
    test('shows what is dragged at once and sends it when let go', () async {
      final store = FakeAnnouncementSettingsStore();
      final controller = _controller(store);
      await controller.load();

      controller
        ..dragVolume(40)
        ..dragVolume(55);
      expect(controller.volume, 55);
      expect(store.saves, isEmpty, reason: 'nothing while it is dragged');

      await controller.commitVolume(60);

      expect(store.saves, ['volume=60']);
      expect(controller.volume, 60);
    });

    test('the music level is its own slider', () async {
      final store = FakeAnnouncementSettingsStore();
      final controller = _controller(store);
      await controller.load();

      controller.dragMusicUnder(10);
      expect(controller.musicUnder, 10);
      expect(controller.volume, 100);

      await controller.commitMusicUnder(0);

      expect(store.saves, ['musicUnder=0']);
      expect(controller.musicUnder, 0);
    });

    test('a failed save goes back to the saved value and says so', () async {
      final store = FakeAnnouncementSettingsStore();
      final controller = _controller(store);
      await controller.load();
      store.saveError = StateError('no');

      await controller.commitVolume(20);

      expect(controller.volume, 100);
      expect(controller.errorKey, AppTextKey.mediaCommandFailed);
    });

    test('the message goes away by itself', () {
      fakeAsync((async) {
        final store = FakeAnnouncementSettingsStore();
        final controller = AnnouncementSettingsController(store: store);
        controller.load();
        async.flushMicrotasks();
        store.saveError = StateError('no');

        controller.commitVolume(20);
        async.flushMicrotasks();
        expect(controller.errorKey, isNotNull);

        async.elapse(const Duration(seconds: 5));
        expect(controller.errorKey, isNull);
        controller.dispose();
      });
    });

    test('two changes in a row are saved one after the other', () async {
      final store = FakeAnnouncementSettingsStore()
        ..saveGate = Completer<void>();
      final controller = _controller(store);
      await controller.load();

      final first = controller.commitVolume(30);
      final second = controller.commitMusicUnder(5);
      await Future<void>.delayed(Duration.zero);
      // The second waits for the first.
      expect(store.saves, ['volume=30']);

      store.saveGate?.complete();
      await Future.wait([first, second]);

      expect(store.saves, ['volume=30', 'musicUnder=5']);
      expect(controller.volume, 30);
      expect(controller.musicUnder, 5);
    });

    test('moved on while it was sent keeps the newer value', () async {
      final store = FakeAnnouncementSettingsStore()
        ..saveGate = Completer<void>();
      final controller = _controller(store);
      await controller.load();

      final saving = controller.commitVolume(30);
      await Future<void>.delayed(Duration.zero);
      controller.dragVolume(45);
      store.saveGate?.complete();
      await saving;

      expect(controller.volume, 45);
    });
  });

  group('without a voice', () {
    FakeAnnouncementSettingsStore withoutVoice() =>
        FakeAnnouncementSettingsStore(
          settings: const AnnouncementSettings(
            available: false,
            enabled: true,
            volumePercent: 100,
            musicUnderPercent: 30,
          ),
        );

    test('nothing can be changed or tested', () async {
      final store = withoutVoice();
      final controller = _controller(store);
      await controller.load();

      await controller.setEnabled(enabled: false);
      controller.dragVolume(10);
      await controller.commitVolume(10);
      await controller.commitMusicUnder(10);
      await controller.playTest();

      expect(controller.isAvailable, isFalse);
      expect(controller.canTest, isFalse);
      expect(store.saves, isEmpty);
      expect(store.spoken, isEmpty);
      expect(controller.volume, 100);
    });
  });

  group('the test announcement', () {
    test('speaks the German example sentence', () async {
      final store = FakeAnnouncementSettingsStore();
      final controller = _controller(store);
      await controller.load();

      await controller.playTest();

      expect(store.spoken, ['In 300 Metern rechts abbiegen.']);
    });

    test('is not offered while the announcements are off', () async {
      final store = FakeAnnouncementSettingsStore();
      final controller = _controller(store);
      await controller.load();
      await controller.setEnabled(enabled: false);

      expect(controller.canTest, isFalse);
      await controller.playTest();

      expect(store.spoken, isEmpty);
    });

    test('cannot be started twice while it runs', () async {
      final store = FakeAnnouncementSettingsStore()
        ..announceGate = Completer<void>();
      final controller = _controller(store);
      await controller.load();

      final first = controller.playTest();
      await Future<void>.delayed(Duration.zero);
      expect(controller.isTesting, isTrue);
      await controller.playTest();
      expect(store.spoken, hasLength(1));

      store.announceGate?.complete();
      await first;
      expect(controller.isTesting, isFalse);
    });

    test('a failure shows the message', () async {
      final store = FakeAnnouncementSettingsStore()
        ..announceError = StateError('no');
      final controller = _controller(store);
      await controller.load();

      await controller.playTest();

      expect(controller.errorKey, AppTextKey.mediaCommandFailed);
      expect(controller.isTesting, isFalse);
    });
  });

  group('mapping to the backend', () {
    test('a state arrives field by field', () {
      final settings = CarnineGrpcService.announcementSettingsFrom(
        pb.VoiceSettings(
          available: true,
          enabled: true,
          volumePercent: 80,
          voice: 'thorsten-low',
          musicUnderPercent: 0,
        ),
      );

      expect(settings.available, isTrue);
      expect(settings.enabled, isTrue);
      expect(settings.volumePercent, 80);
      expect(settings.musicUnderPercent, 0);
      expect(settings.voice, 'thorsten-low');
    });

    test('a request carries only what is given', () {
      final request = CarnineGrpcService.announcementRequestFrom(
        musicUnderPercent: 0,
      );

      expect(request.hasMusicUnderPercent(), isTrue);
      expect(request.musicUnderPercent, 0);
      expect(request.hasEnabled(), isFalse);
      expect(request.hasVolumePercent(), isFalse);
    });

    test('off and 0 are values, not "unset"', () {
      final request = CarnineGrpcService.announcementRequestFrom(
        enabled: false,
        volumePercent: 0,
      );

      expect(request.hasEnabled(), isTrue);
      expect(request.enabled, isFalse);
      expect(request.hasVolumePercent(), isTrue);
      expect(request.volumePercent, 0);
    });
  });
}
