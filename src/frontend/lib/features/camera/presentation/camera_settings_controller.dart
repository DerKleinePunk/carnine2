import 'dart:async';

import 'package:carnine_frontend/features/camera/data/camera_settings_store.dart';
import 'package:carnine_frontend/features/camera/domain/video_device.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:video_grabber/video_grabber.dart';

enum CameraSettingsStatus { loading, ready, offline }

/// State of the camera settings page: the settings the backend keeps, the
/// devices it sees, and saving - every change goes to the backend at once,
/// there is no draft.
///
/// The camera page reads the settings when it opens, so a change shows only
/// from the next opening (`CameraContent`).
class CameraSettingsController extends ChangeNotifier {
  CameraSettingsController({required this._store, Logger? logger})
    : _logger = logger ?? Logger('CameraSettingsController');

  static const _errorDuration = Duration(seconds: 4);

  final CameraSettingsStore _store;
  final Logger _logger;

  CameraSettingsStatus _status = CameraSettingsStatus.loading;
  GrabberConfig? _config;
  List<VideoDevice> _devices = const [];
  bool _isSaving = false;
  AppTextKey? _errorKey;
  Timer? _errorTimer;
  bool _disposed = false;

  CameraSettingsStatus get status => _status;

  /// The settings in effect, `null` until they are loaded.
  GrabberConfig? get config => _config;
  List<VideoDevice> get devices => _devices;
  bool get isSaving => _isSaving;

  /// Why the last change failed, shown briefly.
  AppTextKey? get errorKey => _errorKey;

  /// The saved device if the backend sees it, else `null`.
  VideoDevice? get selectedDevice {
    final path = _config?.device;
    for (final device in _devices) {
      if (device.path == path) {
        return device;
      }
    }
    return null;
  }

  /// The saved device is not among the devices found - unplugged, or a node
  /// that moved. It stays selected and visible, so the setting is not lost.
  bool get isSelectedDeviceMissing => _config != null && selectedDevice == null;

  /// Norm, input and width are the grabber's: a USB camera ignores them.
  bool get areGrabberFieldsEnabled => selectedDevice?.isUsbCamera != true;

  @override
  void dispose() {
    _disposed = true;
    _errorTimer?.cancel();
    super.dispose();
  }

  /// Loads settings and devices. Also the retry after the backend was away.
  Future<void> load() async {
    _status = CameraSettingsStatus.loading;
    notifyListeners();

    try {
      final (config, devices) = await (
        _store.loadCameraSettings(),
        _store.listCameraDevices(),
      ).wait;
      if (_disposed) {
        return;
      }
      _config = config;
      _devices = devices;
      _status = CameraSettingsStatus.ready;
    } on Object catch (error) {
      _logger.warning('Camera settings not available: $error');
      if (_disposed) {
        return;
      }
      _status = CameraSettingsStatus.offline;
    }
    notifyListeners();
  }

  Future<void> selectDevice(String path) {
    return _config?.device == path ? Future.value() : _save(device: path);
  }

  Future<void> selectNorm(VideoNorm norm) {
    return _config?.norm == norm ? Future.value() : _save(norm: norm);
  }

  Future<void> selectInput(int input) {
    return _config?.input == input ? Future.value() : _save(input: input);
  }

  Future<void> selectWidth(int width) {
    return _config?.width == width ? Future.value() : _save(width: width);
  }

  void dismissError() {
    if (_errorKey == null) {
      return;
    }
    _errorTimer?.cancel();
    _errorKey = null;
    notifyListeners();
  }

  /// Saves one change. While a save is on its way further taps are ignored,
  /// so two saves cannot overtake each other.
  Future<void> _save({
    String? device,
    VideoNorm? norm,
    int? input,
    int? width,
  }) async {
    if (_isSaving || _config == null) {
      return;
    }
    _isSaving = true;
    notifyListeners();

    try {
      final saved = await _store.saveCameraSettings(
        device: device,
        norm: norm,
        input: input,
        width: width,
      );
      if (!_disposed) {
        _config = saved;
        _errorKey = null;
      }
    } on Object catch (error) {
      _logger.warning('Saving the camera settings failed: $error');
      if (!_disposed) {
        _errorKey = AppTextKey.mediaCommandFailed;
        _errorTimer?.cancel();
        _errorTimer = Timer(_errorDuration, dismissError);
      }
    } finally {
      if (!_disposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }
}
