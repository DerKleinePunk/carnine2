import 'dart:async';

import 'package:carnine_frontend/core/platform/grpc_endpoint.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart' as pb;
import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';

/// Whether the backend considers the CPU overheated (#70). The backend
/// decides, with hysteresis, so every UI agrees on it.
class ThermalStatus {
  const ThermalStatus({required this.overheated, this.cpuCelsius});

  static const ThermalStatus normal = ThermalStatus(overheated: false);

  final bool overheated;

  /// The reading behind the last change; `null` without a thermal zone.
  final double? cpuCelsius;
}

ThermalStatus thermalStatusFromProto(pb.ThermalStatus status) {
  return ThermalStatus(
    overheated: status.overheated,
    cpuCelsius: status.hasCpuTemperatureCelsius()
        ? status.cpuTemperatureCelsius
        : null,
  );
}

/// Where the dashboard gets the thermal status from.
abstract interface class ThermalStatusSource {
  /// Current status first, then every change, for as long as someone listens.
  Stream<ThermalStatus> get statuses;

  Future<void> dispose();
}

/// [ThermalStatusSource] on `SystemService.StreamThermalStatus`.
///
/// Like the power supply stream: runs while someone listens and reconnects
/// after [retryDelay] when it breaks. The stream opens with the current
/// status, so a reconnect while the CPU is hot reports it again.
class GrpcThermalStatusSource implements ThermalStatusSource {
  GrpcThermalStatusSource({
    ClientChannel Function()? channelFactory,
    this.retryDelay = const Duration(seconds: 2),
    Logger? logger,
  }) : _channelFactory = channelFactory ?? _createDefaultChannel,
       _logger = logger ?? Logger('GrpcThermalStatusSource') {
    _controller = StreamController<ThermalStatus>.broadcast(
      onListen: _connect,
      onCancel: _disconnect,
    );
  }

  final ClientChannel Function() _channelFactory;
  final Duration retryDelay;
  final Logger _logger;
  late final StreamController<ThermalStatus> _controller;
  ClientChannel? _channel;
  StreamSubscription<pb.ThermalStatus>? _subscription;
  Timer? _retry;

  /// Logged once per outage, not on every retry.
  bool _broken = false;

  @override
  Stream<ThermalStatus> get statuses => _controller.stream;

  void _connect() {
    _retry = null;
    final channel = _channel ??= _channelFactory();
    _subscription = pb.SystemServiceClient(channel)
        .streamThermalStatus(pb.Empty())
        .listen(
          _onStatus,
          onError: _onBroken,
          onDone: () => _onBroken('stream closed'),
          cancelOnError: true,
        );
  }

  void _onStatus(pb.ThermalStatus status) {
    if (_broken) {
      _broken = false;
      _logger.info('Thermal status stream back');
    }
    _controller.add(thermalStatusFromProto(status));
  }

  void _onBroken(Object reason) {
    _subscription = null;
    if (!_controller.hasListener) {
      return;
    }
    if (!_broken) {
      _broken = true;
      _logger.warning('Thermal status stream lost, retrying: $reason');
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
      _logger.fine('Error shutting down the thermal status channel: $error');
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
