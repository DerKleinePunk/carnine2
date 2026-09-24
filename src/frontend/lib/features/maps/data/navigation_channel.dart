import 'package:carnine_frontend/core/platform/grpc_endpoint.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart';
import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';

typedef NavigationChannelFactory = ClientChannel Function();

/// Owns one long-lived gRPC channel for the maps feature.
///
/// Like `MediaChannel`: `StreamPositions` is a long-lived stream, which a
/// channel per call cannot serve. [reconnect] tears the channel down so the
/// next [stub] access rebuilds it after the backend restarted.
class NavigationChannel {
  NavigationChannel({NavigationChannelFactory? channelFactory, Logger? logger})
    : _channelFactory = channelFactory ?? _createDefaultChannel,
      _logger = logger ?? Logger('NavigationChannel');

  final NavigationChannelFactory _channelFactory;
  final Logger _logger;

  ClientChannel? _channel;
  NavigationServiceClient? _stub;

  NavigationServiceClient get stub {
    final channel = _channel ??= _channelFactory();
    return _stub ??= NavigationServiceClient(channel);
  }

  Future<void> reconnect() async {
    _logger.info('Rebuilding navigation gRPC channel');
    await shutdown();
  }

  Future<void> shutdown() async {
    final channel = _channel;
    _channel = null;
    _stub = null;
    if (channel == null) {
      return;
    }
    try {
      await channel.shutdown();
    } catch (error, stackTrace) {
      _logger.warning(
        'Error shutting down navigation channel',
        error,
        stackTrace,
      );
    }
  }

  static ClientChannel _createDefaultChannel() {
    return GrpcEndpoint.createChannel(
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
        connectTimeout: Duration(milliseconds: 400),
        connectionTimeout: GrpcEndpoint.connectionLifetime,
        keepAlive: ClientKeepAliveOptions(
          pingInterval: Duration(seconds: 5),
          timeout: Duration(milliseconds: 400),
          permitWithoutCalls: true,
        ),
      ),
    );
  }
}
