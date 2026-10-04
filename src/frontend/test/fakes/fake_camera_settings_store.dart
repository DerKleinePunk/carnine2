import 'dart:async';

import 'package:carnine_frontend/features/camera/data/camera_settings_store.dart';
import 'package:carnine_frontend/features/camera/domain/video_device.dart';
import 'package:video_grabber/video_grabber.dart';

/// Hand-written [CameraSettingsStore] for tests: keeps the settings in
/// memory like the backend does, and records every save in [saves].
class FakeCameraSettingsStore implements CameraSettingsStore {
  FakeCameraSettingsStore({
    this.config = const GrabberConfig(),
    this.devices = const [],
    this.error,
    this.saveError,
  });

  GrabberConfig config;
  List<VideoDevice> devices;

  /// Thrown by loading, to play a backend that is away.
  Object? error;

  /// Thrown by saving, once; cleared after it fired.
  Object? saveError;

  /// Holds loading until completed.
  Completer<void>? gate;

  /// What was saved, one entry per call, e.g. `norm=pal`.
  final List<String> saves = [];

  @override
  Future<GrabberConfig> loadCameraSettings() async {
    await gate?.future;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return config;
  }

  @override
  Future<List<VideoDevice>> listCameraDevices() async {
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return devices;
  }

  @override
  Future<GrabberConfig> saveCameraSettings({
    String? device,
    VideoNorm? norm,
    int? input,
    int? width,
  }) async {
    final failure = saveError;
    if (failure != null) {
      saveError = null;
      throw failure;
    }
    saves.add(
      [
        if (device != null) 'device=$device',
        if (norm != null) 'norm=${norm.name}',
        if (input != null) 'input=$input',
        if (width != null) 'width=$width',
      ].join(','),
    );
    config = GrabberConfig(
      device: device ?? config.device,
      norm: norm ?? config.norm,
      input: input ?? config.input,
      width: width ?? config.width,
    );
    return config;
  }
}

const grabberDevice = VideoDevice(
  path: '/dev/video0',
  name: 'stk1160',
  driver: 'stk1160',
);

const usbCameraDevice = VideoDevice(
  path: '/dev/video1',
  name: 'USB PHY 2.0: USB CAMERA',
  driver: 'uvcvideo',
);
