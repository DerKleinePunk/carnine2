import 'package:carnine_frontend/core/platform/grpc_endpoint.dart';
import 'package:carnine_frontend/features/camera/data/camera_settings_store.dart';
import 'package:carnine_frontend/features/dashboard/data/ui_state_store.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart';
import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';
import 'package:video_grabber/video_grabber.dart';

typedef ClientChannelFactory = ClientChannel Function();

/// Thin gRPC client for backend requests used by the frontend.
///
/// The service keeps transport creation isolated in [GrpcEndpoint] so
/// dashboard widgets don't need to know which transport is active.
class CarnineGrpcService implements UiStateStore, CameraSettingsStore {
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
