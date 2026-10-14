import 'dart:async';

import 'package:carnine_frontend/core/platform/grpc_endpoint.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart' as pb;
import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';

/// Where the dashboard gets the live CPU temperature from. The thermal status
/// only carries the reading of its last change, so the start page reads the
/// health samples instead.
abstract interface class CpuTemperatureSource {
  /// The temperature in °C with every sample, `null` when the board has no
  /// thermal zone; for as long as someone listens.
  Stream<double?> get temperatures;

  Future<void> dispose();
}

/// [CpuTemperatureSource] on `SystemService.StreamSystemMetrics`.
///
/// Like the thermal status stream: runs while someone listens and reconnects
/// after [retryDelay] when it breaks.
class GrpcCpuTemperatureSource implements CpuTemperatureSource {
  GrpcCpuTemperatureSource({
    ClientChannel Function()? channelFactory,
    this.retryDelay = const Duration(seconds: 2),
    Logger? logger,
  }) : _channelFactory = channelFactory ?? _createDefaultChannel,
       _logger = logger ?? Logger('GrpcCpuTemperatureSource') {
    _controller = StreamController<double?>.broadcast(
      onListen: _connect,
      onCancel: _disconnect,
    );
  }

  final ClientChannel Function() _channelFactory;
  final Duration retryDelay;
  final Logger _logger;
  late final StreamController<double?> _controller;
  ClientChannel? _channel;
  StreamSubscription<pb.SystemMetrics>? _subscription;
  Timer? _retry;

  /// Logged once per outage, not on every retry.
  bool _broken = false;

  @override
  Stream<double?> get temperatures => _controller.stream;

  void _connect() {
    _retry = null;
    final channel = _channel ??= _channelFactory();
    _subscription = pb.SystemServiceClient(channel)
        .streamSystemMetrics(pb.Empty())
        .listen(
          _onMetrics,
          onError: _onBroken,
          onDone: () => _onBroken('stream closed'),
          cancelOnError: true,
        );
  }

  void _onMetrics(pb.SystemMetrics metrics) {
    if (_broken) {
      _broken = false;
      _logger.info('System metrics stream back');
    }
    _controller.add(
      metrics.hasCpuTemperatureCelsius() ? metrics.cpuTemperatureCelsius : null,
    );
  }

  void _onBroken(Object reason) {
    _subscription = null;
    if (!_controller.hasListener) {
      return;
    }
    if (!_broken) {
      _broken = true;
      _logger.warning('System metrics stream lost, retrying: $reason');
    }
    _retry ??= Timer(retryDelay, () async {
      await _shutdownChannel();
      if (_controller.hasListener) {
        _connect();
      }
    });
  }

  Future<void> _disconnect() async {
    _retry?.cancel();
    _retry = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _shutdownChannel() async {
    final channel = _channel;
    _channel = null;
    try {
      await channel?.shutdown();
    } catch (error) {
      _logger.fine('Error shutting down the system metrics channel: $error');
    }
  }

  @override
  Future<void> dispose() async {
    await _disconnect();
    await _shutdownChannel();
    await _controller.close();
  }

  static ClientChannel _createDefaultChannel() {
    return GrpcEndpoint.createChannel(
      options: GrpcEndpoint.longLivedChannelOptions,
    );
  }
}
