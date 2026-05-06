import 'package:carnine_frontend/lib/carnine.pbgrpc.dart';
import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';

typedef ClientChannelFactory = ClientChannel Function();

/// Thin gRPC client for backend requests used by the frontend.
///
/// The current bootstrap channel targets localhost TCP for development. The
/// service keeps transport creation isolated so Unix domain sockets can replace
/// it without changing dashboard widgets.
class CarnineGrpcService {
  CarnineGrpcService({
    Logger? logger,
    ClientChannelFactory? channelFactory,
  })  : _logger = logger ?? Logger('CarnineGrpcService'),
        _channelFactory = channelFactory ?? _createDefaultChannel;

  final Logger _logger;
  final ClientChannelFactory _channelFactory;

  /// Fetches engine temperature CAN data through the generated protobuf stub.
  Future<List<CanData>> fetchEngineTemperature() {
    return fetchCanData(sensorId: 'engine_temp');
  }

  /// Fetches CAN data for the requested sensor and always closes the channel.
  Future<List<CanData>> fetchCanData({required String sensorId}) async {
    final channel = _channelFactory();

    try {
      final stub = CarnineServiceClient(channel);
      final response =
          await stub.getCanData(CanDataRequest(sensorId: sensorId));

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
    return ClientChannel(
      'localhost',
      port: 50051,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
  }
}
