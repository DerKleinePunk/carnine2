import 'package:carnine_frontend/data/services/carnine_grpc_service.dart';
import 'package:carnine_frontend/features/camera/domain/video_device.dart';
import 'package:carnine_frontend/features/camera/presentation/camera_settings_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_grabber/video_grabber.dart';

import '../../fakes/fake_camera_settings_store.dart';

void main() {
  late FakeCameraSettingsStore store;
  late CameraSettingsController controller;

  setUp(() {
    store = FakeCameraSettingsStore(
      devices: const [grabberDevice, usbCameraDevice],
    );
    controller = CameraSettingsController(store: store);
  });

  tearDown(() {
    controller.dispose();
  });

  test('loads the settings and the devices', () async {
    expect(controller.status, CameraSettingsStatus.loading);

    await controller.load();

    expect(controller.status, CameraSettingsStatus.ready);
    expect(controller.config, const GrabberConfig());
    expect(controller.devices, hasLength(2));
    expect(controller.selectedDevice, grabberDevice);
  });

  test(
    'a backend that is away leaves it offline, and load tries again',
    () async {
      store.error = StateError('down');
      await controller.load();
      expect(controller.status, CameraSettingsStatus.offline);

      store.error = null;
      await controller.load();

      expect(controller.status, CameraSettingsStatus.ready);
    },
  );

  test('each choice saves only its own field', () async {
    await controller.load();

    await controller.selectNorm(VideoNorm.pal);
    await controller.selectInput(4);
    await controller.selectWidth(720);
    await controller.selectDevice('/dev/video1');

    expect(store.saves, [
      'norm=pal',
      'input=4',
      'width=720',
      'device=/dev/video1',
    ]);
    expect(
      controller.config,
      const GrabberConfig(
        device: '/dev/video1',
        norm: VideoNorm.pal,
        input: 4,
        width: 720,
      ),
    );
  });

  test('choosing what is already set saves nothing', () async {
    await controller.load();

    await controller.selectNorm(VideoNorm.ntsc);
    await controller.selectInput(0);
    await controller.selectWidth(360);
    await controller.selectDevice('/dev/video0');

    expect(store.saves, isEmpty);
  });

  test('a failed save keeps the old value and says so', () async {
    await controller.load();
    store.saveError = StateError('boom');

    await controller.selectNorm(VideoNorm.pal);

    expect(controller.config?.norm, VideoNorm.ntsc);
    expect(controller.errorKey, AppTextKey.mediaCommandFailed);
    expect(controller.isSaving, isFalse);

    controller.dismissError();
    expect(controller.errorKey, isNull);
  });

  test('while a save is on its way further choices are ignored', () async {
    await controller.load();
    final first = controller.selectNorm(VideoNorm.pal);
    final second = controller.selectWidth(720);
    await Future.wait([first, second]);

    expect(store.saves, ['norm=pal']);
  });

  test('norm, input and width are greyed out for a USB camera only', () async {
    store.config = const GrabberConfig(device: '/dev/video1');
    await controller.load();
    expect(controller.selectedDevice?.isUsbCamera, isTrue);
    expect(controller.areGrabberFieldsEnabled, isFalse);

    await controller.selectDevice('/dev/video0');

    expect(controller.areGrabberFieldsEnabled, isTrue);
  });

  test('a driver that is unknown leaves the fields usable', () async {
    store
      ..devices = const [
        VideoDevice(path: '/dev/video0', name: 'x', driver: ''),
      ]
      ..config = const GrabberConfig();
    await controller.load();

    expect(controller.areGrabberFieldsEnabled, isTrue);
  });

  test('a saved device that is not plugged in stays selected', () async {
    store.config = const GrabberConfig(device: '/dev/video7');
    await controller.load();

    expect(controller.selectedDevice, isNull);
    expect(controller.isSelectedDeviceMissing, isTrue);
    expect(controller.config?.device, '/dev/video7');
  });

  test('the request carries only the fields that are given', () {
    final request = CarnineGrpcService.cameraSettingsRequestFrom(
      norm: VideoNorm.pal,
      width: 720,
    );

    expect(request.hasDevice(), isFalse);
    expect(request.hasInput(), isFalse);
    expect(request.norm, CameraNorm.CAMERA_NORM_PAL);
    expect(request.width, 720);
  });

  test('input 0 is sent, it is a value and not "unset"', () {
    final request = CarnineGrpcService.cameraSettingsRequestFrom(input: 0);

    expect(request.hasInput(), isTrue);
    expect(request.input, 0);
  });
}
