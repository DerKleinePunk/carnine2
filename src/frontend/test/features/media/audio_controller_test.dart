import 'package:carnine_frontend/features/media/domain/models/audio_event.dart';
import 'package:carnine_frontend/features/media/presentation/audio_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_media_repository.dart';

void main() {
  late FakeMediaRepository repository;
  late AudioController controller;

  setUp(() {
    repository = FakeMediaRepository()..volumePercent = 60;
    controller = AudioController(repository: repository);
  });

  tearDown(() {
    controller.dispose();
  });

  test('start loads the current backend volume', () async {
    await controller.start();

    expect(controller.volumePercent, 60);
    expect(controller.isMuted, isFalse);
  });

  test('setVolume applies immediately and confirms with the backend', () async {
    await controller.start();

    await controller.setVolume(35);

    expect(controller.volumePercent, 35);
    expect(repository.commands, contains('setVolume:35'));
  });

  test('setVolume clamps out-of-range values', () async {
    await controller.start();

    await controller.setVolume(150);
    expect(controller.volumePercent, 100);

    await controller.setVolume(-10);
    expect(controller.volumePercent, 0);
  });

  test('toggleMute mutes to zero and restores the previous volume', () async {
    await controller.start();
    expect(controller.volumePercent, 60);

    await controller.toggleMute();
    expect(controller.isMuted, isTrue);
    expect(controller.volumePercent, 0);

    await controller.toggleMute();
    expect(controller.isMuted, isFalse);
    expect(controller.volumePercent, 60);
  });

  test('an AUDIO_ERROR event sets the error banner key', () async {
    await controller.start();

    repository.audioEventsController.add(
      const AudioEvent(kind: AudioEventKind.error, message: 'boom'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.bannerKey, AppTextKey.mediaAudioErrorBanner);
  });

  test(
    'an AUDIO_DEVICE_CHANGED event sets the device-changed banner key',
    () async {
      await controller.start();

      repository.audioEventsController.add(
        const AudioEvent(kind: AudioEventKind.deviceChanged, message: 'usb'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.bannerKey, AppTextKey.mediaAudioDeviceChangedBanner);
    },
  );

  test('internal engine lifecycle events never surface a banner', () async {
    await controller.start();

    for (final kind in [
      AudioEventKind.ready,
      AudioEventKind.sourceStarted,
      AudioEventKind.sourcePauseRequested,
      AudioEventKind.sourceResumeRequested,
      AudioEventKind.sourceStopRequested,
      AudioEventKind.decoderStopped,
      AudioEventKind.sourceRemoved,
    ]) {
      repository.audioEventsController.add(AudioEvent(kind: kind, message: ''));
    }
    await Future<void>.delayed(Duration.zero);

    expect(controller.bannerKey, isNull);
  });

  test('the banner auto-dismisses after its timeout', () {
    fakeAsync((async) {
      controller.start();
      async.flushMicrotasks();

      repository.audioEventsController.add(
        const AudioEvent(kind: AudioEventKind.error, message: 'boom'),
      );
      async.flushMicrotasks();
      expect(controller.bannerKey, isNotNull);

      async.elapse(const Duration(seconds: 5));
      expect(controller.bannerKey, isNull);
    });
  });

  test('dismissBanner clears it early', () async {
    await controller.start();

    repository.audioEventsController.add(
      const AudioEvent(kind: AudioEventKind.error, message: 'boom'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.bannerKey, isNotNull);

    controller.dismissBanner();

    expect(controller.bannerKey, isNull);
  });
}
