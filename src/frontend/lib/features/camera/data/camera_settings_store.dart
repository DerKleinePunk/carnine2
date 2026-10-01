import 'package:video_grabber/video_grabber.dart';

/// Where the camera page gets device, input and norm of the reversing
/// camera from. The backend keeps them (CameraService); the frontend never
/// stores them itself.
abstract interface class CameraSettingsStore {
  Future<GrabberConfig> loadCameraSettings();
}
