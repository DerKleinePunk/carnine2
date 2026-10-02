/// A video device the backend found (`CameraService.ListCameraDevices`).
class VideoDevice {
  const VideoDevice({
    required this.path,
    required this.name,
    required this.driver,
  });

  /// The V4L2 node, e.g. `/dev/video0`.
  final String path;

  /// What the kernel calls it, e.g. `USB PHY 2.0: USB CAMERA`.
  final String name;

  /// The kernel driver: `stk1160` for the grabber, `uvcvideo` for a USB
  /// camera, empty when unknown.
  final String driver;

  /// A USB camera brings its own picture size: norm, input and width of the
  /// grabber do nothing for it.
  bool get isUsbCamera => driver == 'uvcvideo';
}
