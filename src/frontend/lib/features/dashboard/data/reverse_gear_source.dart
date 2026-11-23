import 'dart:async';

import 'package:carnine_frontend/core/platform/grpc_endpoint.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart' as pb;
import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';

/// Where the reverse gear is (#137, #191). [unknown] is never "out": the
/// line cannot be read, or the demo source has not been set yet.
enum ReverseGear { unknown, out, engaged }

/// What the backend says about the reverse gear.
class ReverseGearStatus {
  const ReverseGearStatus({required this.configured, required this.gear});

  /// No source in the configuration; the interface does nothing.
  static const ReverseGearStatus none = ReverseGearStatus(
    configured: false,
    gear: ReverseGear.unknown,
  );

  final bool configured;
  final ReverseGear gear;
}

ReverseGearStatus reverseGearStatusFromProto(pb.ReverseGearStatus status) {
  if (!status.configured) {
    return ReverseGearStatus.none;
  }
  return ReverseGearStatus(
    configured: true,
    gear: switch (status.gear) {
      pb.ReverseGear.REVERSE_GEAR_IN => ReverseGear.engaged,
      pb.ReverseGear.REVERSE_GEAR_OUT => ReverseGear.out,
      _ => ReverseGear.unknown,
    },
  );
}

/// Where the dashboard gets the reverse gear from.
abstract interface class ReverseGearSource {
  /// Current status first, then every change, for as long as someone listens.
  Stream<ReverseGearStatus> get statuses;

  Future<void> dispose();
}

/// [ReverseGearSource] on `SystemService.StreamReverseGear`.
///
/// Like the power supply stream: runs while someone listens and reconnects
/// after [retryDelay] when it breaks. The stream opens with the current
/// status, so a gear that is in at start brings the camera at once.
class GrpcReverseGearSource implements ReverseGearSource {
  GrpcReverseGearSource({
    ClientChannel Function()? channelFactory,
    this.retryDelay = const Duration(seconds: 2),
    Logger? logger,
  }) : _channelFactory = channelFactory ?? _createDefaultChannel,
       _logger = logger ?? Logger('GrpcReverseGearSource') {
    _controller = StreamController<ReverseGearStatus>.broadcast(
      onListen: _connect,
      onCancel: _disconnect,
    );
  }

  final ClientChannel Function() _channelFactory;
  final Duration retryDelay;
  final Logger _logger;
  late final StreamController<ReverseGearStatus> _controller;
  ClientChannel? _channel;
  StreamSubscription<pb.ReverseGearStatus>? _subscription;
  Timer? _retry;

  /// Logged once per outage, not on every retry.
  bool _broken = false;

  @override
  Stream<ReverseGearStatus> get statuses => _controller.stream;

  void _connect() {
    _retry = null;
    final channel = _channel ??= _channelFactory();
    _subscription = pb.SystemServiceClient(channel)
        .streamReverseGear(pb.Empty())
        .listen(
          _onStatus,
          onError: _onBroken,
          onDone: () => _onBroken('stream closed'),
          cancelOnError: true,
        );
  }

  void _onStatus(pb.ReverseGearStatus status) {
    if (_broken) {
      _broken = false;
      _logger.info('Reverse gear stream back');
    }
    _controller.add(reverseGearStatusFromProto(status));
  }

  void _onBroken(Object reason) {
    _subscription = null;
    if (!_controller.hasListener) {
      return;
    }
    if (!_broken) {
      _broken = true;
      _logger.warning('Reverse gear stream lost, retrying: $reason');
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
      _logger.fine('Error shutting down the reverse gear channel: $error');
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
