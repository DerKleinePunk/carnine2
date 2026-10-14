import 'package:carnine_frontend/core/platform/grpc_endpoint.dart';
import 'package:carnine_frontend/features/camera/data/camera_settings_store.dart';
import 'package:carnine_frontend/features/camera/domain/video_device.dart';
import 'package:carnine_frontend/features/dashboard/data/ui_state_store.dart';
import 'package:carnine_frontend/features/settings/data/exit_password_store.dart';
import 'package:carnine_frontend/features/settings/data/announcement_settings_store.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart';
import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';
import 'package:video_grabber/video_grabber.dart';

typedef ClientChannelFactory = ClientChannel Function();

/// Thin gRPC client for backend requests used by the frontend.
///
/// The service keeps transport creation isolated in [GrpcEndpoint] so
/// dashboard widgets don't need to know which transport is active.
class CarnineGrpcService
    implements
        UiStateStore,
        CameraSettingsStore,
        ExitPasswordStore,
        AnnouncementSettingsStore {
  CarnineGrpcService({Logger? logger, ClientChannelFactory? channelFactory})
    : _logger = logger ?? Logger('CarnineGrpcService'),
      _channelFactory = channelFactory ?? _createDefaultChannel;

  final Logger _logger;
  final ClientChannelFactory _channelFactory;

  /// Reports that the UI has rendered its first frame.
  Future<void> reportUiReady() async {
    final channel = _channelFactory();

    try {
      final stub = SystemServiceClient(channel);
      final response = await stub.reportUiReady(Empty());
      if (!response.success) {
        throw StateError(response.message);
      }
      _logger.info('Backend acknowledged UI readiness');
    } finally {
      await channel.shutdown();
    }
  }

  @override
  Future<String> loadLastPage() async {
    final channel = _channelFactory();
    try {
      final stub = SystemServiceClient(channel);
      final state = await stub.getUiState(Empty());
      return state.lastPage;
    } finally {
      await channel.shutdown();
    }
  }

  @override
  Future<void> saveLastPage(String page) async {
    final channel = _channelFactory();
    try {
      final stub = SystemServiceClient(channel);
      final response = await stub.saveUiState(UiState(lastPage: page));
      if (!response.success) {
        throw StateError(response.message);
      }
    } finally {
      await channel.shutdown();
    }
  }

  @override
  Future<String> loadLanguage() async {
    final channel = _channelFactory();
    try {
      final stub = SystemServiceClient(channel);
      final state = await stub.getUiState(Empty());
      return state.language;
    } finally {
      await channel.shutdown();
    }
  }

  /// Sends only the language, so the saved page stays (and the other way
  /// round in [saveLastPage]).
  @override
  Future<void> saveLanguage(String languageCode) async {
    final channel = _channelFactory();
    try {
      final stub = SystemServiceClient(channel);
      final response = await stub.saveUiState(UiState(language: languageCode));
      if (!response.success) {
        throw StateError(response.message);
      }
    } finally {
      await channel.shutdown();
    }
  }

  /// The camera settings in effect, as the backend keeps them.
  @override
  Future<GrabberConfig> loadCameraSettings() async {
    final channel = _channelFactory();
    try {
      final settings = await CameraServiceClient(
        channel,
      ).getCameraSettings(Empty());
      return grabberConfigFrom(settings);
    } finally {
      await channel.shutdown();
    }
  }

  @override
  Future<List<VideoDevice>> listCameraDevices() async {
    final channel = _channelFactory();
    try {
      final response = await CameraServiceClient(
        channel,
      ).listCameraDevices(Empty());
      return [
        for (final device in response.devices)
          VideoDevice(
            path: device.path,
            name: device.name,
            driver: device.driver,
          ),
      ];
    } finally {
      await channel.shutdown();
    }
  }

  @override
  Future<GrabberConfig> saveCameraSettings({
    String? device,
    VideoNorm? norm,
    int? input,
    int? width,
  }) async {
    final channel = _channelFactory();
    try {
      final saved = await CameraServiceClient(channel).saveCameraSettings(
        cameraSettingsRequestFrom(
          device: device,
          norm: norm,
          input: input,
          width: width,
        ),
      );
      return grabberConfigFrom(saved);
    } finally {
      await channel.shutdown();
    }
  }

  /// A request that carries only the fields that are given - the backend
  /// saves just those.
  static CameraSettings cameraSettingsRequestFrom({
    String? device,
    VideoNorm? norm,
    int? input,
    int? width,
  }) {
    final request = CameraSettings();
    if (device != null) {
      request.device = device;
    }
    if (norm != null) {
      request.norm = switch (norm) {
        VideoNorm.pal => CameraNorm.CAMERA_NORM_PAL,
        VideoNorm.ntsc => CameraNorm.CAMERA_NORM_NTSC,
      };
    }
    if (input != null) {
      request.input = input;
    }
    if (width != null) {
      request.width = width;
    }
    return request;
  }

  /// What the grabber needs from the backend's settings; a field the backend
  /// left out keeps the grabber's default.
  static GrabberConfig grabberConfigFrom(CameraSettings settings) {
    const defaults = GrabberConfig();
    return GrabberConfig(
      device: settings.hasDevice() ? settings.device : defaults.device,
      input: settings.hasInput() ? settings.input : defaults.input,
      norm: switch (settings.norm) {
        CameraNorm.CAMERA_NORM_PAL => VideoNorm.pal,
        CameraNorm.CAMERA_NORM_NTSC => VideoNorm.ntsc,
        _ => defaults.norm,
      },
      // The grabber takes only 360 or 720; anything else keeps its default
      // rather than failing the page.
      width: settings.width == 720 || settings.width == 360
          ? settings.width
          : defaults.width,
    );
  }

  /// An announcement call that gets no answer in this time failed. A sentence
  /// the voice has not made yet takes several seconds.
  static const Duration _voiceCallTimeout = Duration(seconds: 15);

  @override
  Future<AnnouncementSettings> loadAnnouncementSettings() async {
    final channel = _channelFactory();
    try {
      final settings = await NavigationServiceClient(channel).getVoiceSettings(
        Empty(),
        options: CallOptions(timeout: _voiceCallTimeout),
      );
      return announcementSettingsFrom(settings);
    } finally {
      await channel.shutdown();
    }
  }

  @override
  Future<AnnouncementSettings> saveAnnouncementSettings({
    bool? enabled,
    int? volumePercent,
    int? musicUnderPercent,
  }) async {
    final channel = _channelFactory();
    try {
      final saved = await NavigationServiceClient(channel).setVoiceSettings(
        announcementRequestFrom(
          enabled: enabled,
          volumePercent: volumePercent,
          musicUnderPercent: musicUnderPercent,
        ),
        options: CallOptions(timeout: _voiceCallTimeout),
      );
      return announcementSettingsFrom(saved);
    } finally {
      await channel.shutdown();
    }
  }

  @override
  Future<void> announce(String text) async {
    final channel = _channelFactory();
    try {
      await NavigationServiceClient(channel).announce(
        AnnounceRequest(
          text: text,
          priority: AnnouncementPriority.ANNOUNCEMENT_PRIORITY_MANEUVER,
        ),
        options: CallOptions(timeout: _voiceCallTimeout),
      );
    } finally {
      await channel.shutdown();
    }
  }

  static AnnouncementSettings announcementSettingsFrom(VoiceSettings settings) {
    return AnnouncementSettings(
      available: settings.available,
      enabled: settings.enabled,
      volumePercent: settings.volumePercent,
      musicUnderPercent: settings.musicUnderPercent,
      voice: settings.voice,
    );
  }

  /// A request that carries only the fields that are given - the backend
  /// saves just those.
  static SetVoiceSettingsRequest announcementRequestFrom({
    bool? enabled,
    int? volumePercent,
    int? musicUnderPercent,
  }) {
    final request = SetVoiceSettingsRequest();
    if (enabled != null) {
      request.enabled = enabled;
    }
    if (volumePercent != null) {
      request.volumePercent = volumePercent;
    }
    if (musicUnderPercent != null) {
      request.musicUnderPercent = musicUnderPercent;
    }
    return request;
  }

  /// A password call that gets no answer in this time did not work.
  static const Duration _passwordCallTimeout = Duration(seconds: 5);

  @override
  Future<bool> verify(String password) async {
    final channel = _channelFactory();
    try {
      final check = await SystemServiceClient(channel).verifyExitPassword(
        ExitPasswordRequest(password: password),
        options: CallOptions(timeout: _passwordCallTimeout),
      );
      return check.valid;
    } catch (error) {
      throw exitPasswordExceptionFrom(error);
    } finally {
      await channel.shutdown();
    }
  }

  @override
  Future<void> change({required String current, required String next}) async {
    final channel = _channelFactory();
    try {
      final response = await SystemServiceClient(channel).setExitPassword(
        SetExitPasswordRequest(currentPassword: current, newPassword: next),
        options: CallOptions(timeout: _passwordCallTimeout),
      );
      if (!response.success) {
        throw ExitPasswordException(
          ExitPasswordFailure.failed,
          response.message,
        );
      }
    } on ExitPasswordException {
      rethrow;
    } catch (error) {
      throw exitPasswordExceptionFrom(error);
    } finally {
      await channel.shutdown();
    }
  }

  /// What a failed password call means for the user. The backend's own
  /// message is kept for the log only, since it is English.
  static ExitPasswordException exitPasswordExceptionFrom(Object error) {
    if (error is GrpcError) {
      final failure = switch (error.code) {
        StatusCode.permissionDenied => ExitPasswordFailure.wrongCurrent,
        StatusCode.invalidArgument => ExitPasswordFailure.rejected,
        StatusCode.unavailable ||
        StatusCode.deadlineExceeded ||
        StatusCode.cancelled => ExitPasswordFailure.unreachable,
        _ => ExitPasswordFailure.failed,
      };
      return ExitPasswordException(failure, error.message ?? '');
    }
    // No answer at all: the socket is not there, or the call was cut off.
    return ExitPasswordException(
      ExitPasswordFailure.unreachable,
      error.toString(),
    );
  }

  /// Fetches engine temperature CAN data through the generated protobuf stub.
  Future<List<CanData>> fetchEngineTemperature() {
    return fetchCanData(sensorId: 'engine_temp');
  }

  /// Fetches CAN data for the requested sensor and always closes the channel.
  Future<List<CanData>> fetchCanData({required String sensorId}) async {
    final channel = _channelFactory();

    try {
      final stub = CarnineServiceClient(channel);
      final response = await stub.getCanData(
        CanDataRequest(sensorId: sensorId),
      );

      _logger.info('Received ${response.data.length} CAN data points');
      return List<CanData>.unmodifiable(response.data);
    } catch (error, stackTrace) {
      _logger.severe(
        'gRPC request failed for sensor $sensorId',
        error,
        stackTrace,
      );
      rethrow;
    } finally {
      await channel.shutdown();
    }
  }

  static ClientChannel _createDefaultChannel() {
    return GrpcEndpoint.createChannel(
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
        connectionTimeout: GrpcEndpoint.connectionLifetime,
      ),
    );
  }
}
