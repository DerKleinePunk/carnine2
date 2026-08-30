import 'package:carnine_frontend/lib/carnine.pbgrpc.dart';
import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';

typedef MediaChannelFactory = ClientChannel Function();

/// Owns a single, long-lived gRPC channel for the media feature.
///
/// `CarnineGrpcService` creates a channel per call and shuts it down
/// immediately afterwards, which cannot serve the long-lived
/// `StreamPlayerEvents`/`StreamLibraryEvents` streams this feature depends
/// on. This class keeps one channel alive instead and exposes [reconnect]
/// for the connection-loss recovery loop in `MediaController`.
class MediaChannel {
  MediaChannel({
    MediaChannelFactory? channelFactory,
    Logger? logger,
  })  : _channelFactory = channelFactory ?? _createDefaultChannel,
        _logger = logger ?? Logger('MediaChannel');

  final MediaChannelFactory _channelFactory;
  final Logger _logger;

  ClientChannel? _channel;
  MediaServiceClient? _stub;

  /// The client stub bound to the current channel, created lazily and
  /// reused across calls.
  MediaServiceClient get stub {
    final channel = _channel ??= _channelFactory();
    return _stub ??= MediaServiceClient(channel);
  }

  Stream<ConnectionState> get connectionStates {
    final channel = _channel ??= _channelFactory();
    return channel.onConnectionStateChanged;
  }

  /// Tears down the current channel so the next [stub]/[connectionStates]
  /// access rebuilds it from scratch.
  Future<void> reconnect() async {
    _logger.info('Rebuilding media gRPC channel');
    final channel = _channel;
    _channel = null;
    _stub = null;

    if (channel == null) {
      return;
    }

    try {
      await channel.shutdown();
    } catch (error, stackTrace) {
      _logger.warning('Error shutting down media channel', error, stackTrace);
    }
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
      _logger.warning('Error shutting down media channel', error, stackTrace);
    }
  }

  static ClientChannel _createDefaultChannel() {
    return ClientChannel(
      'localhost',
      port: 50051,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
        connectTimeout: Duration(milliseconds: 400),
        keepAlive: ClientKeepAliveOptions(
          pingInterval: Duration(seconds: 5),
          timeout: Duration(milliseconds: 400),
          permitWithoutCalls: true,
        ),
      ),
    );
  }
}
