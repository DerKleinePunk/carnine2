import 'package:carnine_frontend/core/platform/grpc_endpoint.dart';
import 'package:carnine_frontend/features/dashboard/data/ui_state_store.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart';
import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';

typedef ClientChannelFactory = ClientChannel Function();

/// Thin gRPC client for backend requests used by the frontend.
///
/// The service keeps transport creation isolated in [GrpcEndpoint] so
/// dashboard widgets don't need to know which transport is active.
class CarnineGrpcService implements UiStateStore {
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
    } catch (error, stackTrace) {
      _logger.severe('Could not report UI readiness', error, stackTrace);
      rethrow;
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
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
  }
}
