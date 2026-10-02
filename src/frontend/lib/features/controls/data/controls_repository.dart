import 'dart:async';

import 'package:carnine_frontend/core/platform/grpc_endpoint.dart';
import 'package:carnine_frontend/features/controls/domain/control.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart' as pb;
import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';

/// Where the Technik page gets its controls and their states from, and where
/// it sends changes. The backend keeps all of it; the frontend stores
/// nothing (`ControlService`, #86).
abstract interface class ControlsRepository {
  /// The controls in the order of the configuration. Empty when none is set
  /// up. A control of a kind the frontend does not know is left out.
  Future<List<ControlDefinition>> loadControls();

  /// The state of every control first, then each change - also changes made
  /// by other clients or the backend. Ends with an error when the connection
  /// breaks; listening again starts over.
  Stream<ControlValue> controlStates();

  /// Switches [id] and returns the state now in effect.
  Future<ControlValue> setOn(String id, {required bool on});

  /// Sets the level of [id] and returns the state now in effect.
  Future<ControlValue> setLevel(String id, {required int level});

  Future<void> dispose();
}

/// The control as the frontend knows it, or `null` for a kind it cannot show.
ControlDefinition? controlDefinitionFrom(pb.Control control) {
  final kind = switch (control.type) {
    pb.ControlType.CONTROL_TYPE_SWITCH => ControlKind.toggle,
    pb.ControlType.CONTROL_TYPE_SLIDER => ControlKind.slider,
    _ => null,
  };
  if (kind == null) {
    return null;
  }
  // A slider with no usable range falls back to 0 to 100.
  final hasRange = control.max > control.min;
  return ControlDefinition(
    id: control.id,
    name: control.name,
    kind: kind,
    min: hasRange ? control.min : 0,
    max: hasRange ? control.max : 100,
  );
}

ControlValue controlValueFrom(pb.ControlState state) {
  return ControlValue(
    id: state.id,
    isAvailable: state.available,
    isOn: state.hasOn() ? state.on : null,
    level: state.hasLevel() ? state.level : null,
  );
}

/// [ControlsRepository] on `ControlService`, over one long-lived channel
/// that grpc-dart opens again by itself when the backend was away.
class GrpcControlsRepository implements ControlsRepository {
  GrpcControlsRepository({
    ClientChannel Function()? channelFactory,
    Logger? logger,
  }) : _channelFactory = channelFactory ?? _createDefaultChannel,
       _logger = logger ?? Logger('GrpcControlsRepository');

  /// A command that gets no answer in this time failed.
  static const Duration _callTimeout = Duration(seconds: 5);

  final ClientChannel Function() _channelFactory;
  final Logger _logger;
  ClientChannel? _channel;

  pb.ControlServiceClient get _client {
    final channel = _channel ??= _channelFactory();
    return pb.ControlServiceClient(channel);
  }

  @override
  Future<List<ControlDefinition>> loadControls() async {
    final list = await _client.getControls(
      pb.Empty(),
      options: CallOptions(timeout: _callTimeout),
    );
    return [
      for (final control in list.controls) ?controlDefinitionFrom(control),
    ];
  }

  @override
  Stream<ControlValue> controlStates() {
    late final StreamController<ControlValue> out;
    StreamSubscription<pb.ControlState>? subscription;
    out = StreamController<ControlValue>(
      onListen: () {
        subscription = _client
            .streamControlStates(pb.Empty())
            .listen(
              (state) => out.add(controlValueFrom(state)),
              onError: out.addError,
              onDone: out.close,
              cancelOnError: true,
            );
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<ControlValue> setOn(String id, {required bool on}) async {
    final state = await _client.setControlState(
      pb.SetControlStateRequest(id: id, on: on),
      options: CallOptions(timeout: _callTimeout),
    );
    return controlValueFrom(state);
  }

  @override
  Future<ControlValue> setLevel(String id, {required int level}) async {
    final state = await _client.setControlState(
      pb.SetControlStateRequest(id: id, level: level),
      options: CallOptions(timeout: _callTimeout),
    );
    return controlValueFrom(state);
  }

  @override
  Future<void> dispose() async {
    final channel = _channel;
    _channel = null;
    try {
      await channel?.shutdown();
    } catch (error) {
      _logger.fine('Error shutting down the controls channel: $error');
    }
  }

  static ClientChannel _createDefaultChannel() {
    return GrpcEndpoint.createChannel(
      options: GrpcEndpoint.longLivedChannelOptions,
    );
  }
}
