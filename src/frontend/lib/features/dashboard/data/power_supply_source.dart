import 'dart:async';

import 'package:carnine_frontend/core/platform/grpc_endpoint.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart' as pb;
import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';

/// The car power supply's state machine (docs/23-power-supply.md).
enum PowerSupplyState { unknown, idle, powerOn, piBoot, run, powerOff }

/// What the backend last heard from the car power supply.
class PowerSupplyStatus {
  const PowerSupplyStatus({
    required this.configured,
    required this.connected,
    this.ignition,
    this.state = PowerSupplyState.unknown,
    this.inputVolts,
  });

  /// No supply configured on this device; nothing to show.
  static const PowerSupplyStatus none = PowerSupplyStatus(
    configured: false,
    connected: false,
  );

  final bool configured;

  /// The supply sent something within the last three seconds.
  final bool connected;

  /// Ignition (KL15); `null` until the supply reported it.
  final bool? ignition;
  final PowerSupplyState state;
  final double? inputVolts;

  /// The supply is about to cut the power: ignition off, or its watchdog
  /// fired. The backend does not shut the Pi down yet (#36).
  bool get switchingOff =>
      configured &&
      connected &&
      (ignition == false || state == PowerSupplyState.powerOff);
}

PowerSupplyStatus powerSupplyStatusFromProto(pb.PowerSupplyStatus status) {
  if (!status.configured) {
    return PowerSupplyStatus.none;
  }
  return PowerSupplyStatus(
    configured: true,
    connected: status.connected,
    ignition: status.hasIgnition() ? status.ignition : null,
    state: switch (status.state) {
      pb.PowerSupplyState.POWER_SUPPLY_STATE_IDLE => PowerSupplyState.idle,
      pb.PowerSupplyState.POWER_SUPPLY_STATE_POWER_ON =>
        PowerSupplyState.powerOn,
      pb.PowerSupplyState.POWER_SUPPLY_STATE_PI_BOOT => PowerSupplyState.piBoot,
      pb.PowerSupplyState.POWER_SUPPLY_STATE_RUN => PowerSupplyState.run,
      pb.PowerSupplyState.POWER_SUPPLY_STATE_POWER_OFF =>
        PowerSupplyState.powerOff,
      _ => PowerSupplyState.unknown,
    },
    inputVolts: status.hasInputVoltageVolts() ? status.inputVoltageVolts : null,
  );
}

/// Where the dashboard gets the power supply status from.
abstract interface class PowerSupplySource {
  /// Current status first, then every change, for as long as someone listens.
  Stream<PowerSupplyStatus> get statuses;

  Future<void> dispose();
}

/// [PowerSupplySource] on `SystemService.StreamPowerSupplyStatus`.
///
/// The stream runs while someone listens and reconnects after [retryDelay]
/// when it breaks (backend restart, socket gone), like the position stream.
class GrpcPowerSupplySource implements PowerSupplySource {
  GrpcPowerSupplySource({
    ClientChannel Function()? channelFactory,
    this.retryDelay = const Duration(seconds: 2),
    Logger? logger,
  }) : _channelFactory = channelFactory ?? _createDefaultChannel,
       _logger = logger ?? Logger('GrpcPowerSupplySource') {
    _controller = StreamController<PowerSupplyStatus>.broadcast(
      onListen: _connect,
      onCancel: _disconnect,
    );
  }

  final ClientChannel Function() _channelFactory;
  final Duration retryDelay;
  final Logger _logger;
  late final StreamController<PowerSupplyStatus> _controller;
  ClientChannel? _channel;
  StreamSubscription<pb.PowerSupplyStatus>? _subscription;
  Timer? _retry;

  /// Logged once per outage, not on every retry.
  bool _broken = false;

  @override
  Stream<PowerSupplyStatus> get statuses => _controller.stream;

  void _connect() {
    _retry = null;
    final channel = _channel ??= _channelFactory();
    _subscription = pb.SystemServiceClient(channel)
        .streamPowerSupplyStatus(pb.Empty())
        .listen(
          _onStatus,
          onError: _onBroken,
          onDone: () => _onBroken('stream closed'),
          cancelOnError: true,
        );
  }

  void _onStatus(pb.PowerSupplyStatus status) {
    if (_broken) {
      _broken = false;
      _logger.info('Power supply stream back');
    }
    _controller.add(powerSupplyStatusFromProto(status));
  }

  void _onBroken(Object reason) {
    _subscription = null;
    if (!_controller.hasListener) {
      return;
    }
    if (!_broken) {
      _broken = true;
      _logger.warning('Power supply stream lost, retrying: $reason');
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
      _logger.fine('Error shutting down the power supply channel: $error');
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
