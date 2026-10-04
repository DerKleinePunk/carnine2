import 'package:carnine_frontend/features/camera/domain/video_device.dart';
import 'package:video_grabber/video_grabber.dart';

/// Where the camera page gets device, input and norm of the reversing
/// camera from. The backend keeps them (CameraService); the frontend never
/// stores them itself.
abstract interface class CameraSettingsStore {
  Future<GrabberConfig> loadCameraSettings();

  /// The video devices the backend sees, without the Pi's own nodes.
  Future<List<VideoDevice>> listCameraDevices();

  /// Saves only the fields that are given and returns the settings now in
  /// effect. Nothing is saved when one value is invalid.
  Future<GrabberConfig> saveCameraSettings({
    String? device,
    VideoNorm? norm,
    int? input,
    int? width,
  });
}
