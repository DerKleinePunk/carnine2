import 'dart:async';

import 'package:carnine_frontend/features/maps/data/navigation_channel.dart';
import 'package:carnine_frontend/features/maps/data/navigation_mappers.dart';
import 'package:carnine_frontend/features/maps/domain/navigation_failure.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart' as pb;
import 'package:grpc/grpc.dart';
import 'package:local_map/local_map.dart';
import 'package:logging/logging.dart';

/// Language for instructions, asked per call so a language switch in the
/// settings applies to the next route.
typedef LanguageTag = String Function();

const _callTimeout = Duration(seconds: 10);

/// [RoutingProvider] on `NavigationService.ComputeRoute`.
class GrpcRoutingProvider implements RoutingProvider {
  GrpcRoutingProvider(this._channel, {required this.language});

  final NavigationChannel _channel;
  final LanguageTag language;

  /// The last failed [route] call, `null` after a success. The library only
  /// keeps the message; the page needs the kind for a localized text.
  NavigationFailure? lastFailure;

  @override
  Future<RoutingResult> route({LatLng? start, required LatLng end}) async {
    final request = pb.ComputeRouteRequest(
      destination: latLonToProto(end),
      language: language(),
    );
    // Without a start the backend routes from its own GPS fix (ADR-021).
    if (start != null) {
      request.origin = latLonToProto(start);
    }
    try {
      final route = await _channel.stub.computeRoute(
        request,
        options: CallOptions(timeout: _callTimeout),
      );
      lastFailure = null;
      return routeFromProto(route);
    } catch (error) {
      throw lastFailure = navigationFailureFrom(error);
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final status = await _channel.stub.getNavigationStatus(pb.Empty());
      return status.routingAvailable;
    } catch (_) {
      return false;
    }
  }
}

/// [PlaceSearch] on `NavigationService.SearchPlaces`.
class GrpcPlaceSearch implements PlaceSearch {
  GrpcPlaceSearch(this._channel);

  final NavigationChannel _channel;

  @override
  Future<List<GeocoderResult>> searchPlaces(
    String query, {
    int limit = 15,
    LatLng? near,
  }) async {
    final request = pb.SearchPlacesRequest(query: query, limit: limit);
    if (near != null) {
      request.near = latLonToProto(near);
    }
    try {
      final response = await _channel.stub.searchPlaces(
        request,
        options: CallOptions(timeout: _callTimeout),
      );
      return [for (final p in response.places) placeFromProto(p)];
    } catch (error) {
      throw navigationFailureFrom(error);
    }
  }
}

/// [PositionSource] on `NavigationService.StreamPositions`.
///
/// The stream runs while someone listens. When it breaks (backend restart,
/// socket gone) it reconnects after [retryDelay] - a lost stream must not
/// leave the map standing still without anyone noticing.
class GrpcPositionSource implements PositionSource {
  GrpcPositionSource(
    this._channel, {
    this.retryDelay = const Duration(seconds: 2),
    Logger? logger,
  }) : _logger = logger ?? Logger('GrpcPositionSource') {
    _controller = StreamController<PositionFix>.broadcast(
      onListen: _connect,
      onCancel: _disconnect,
    );
  }

  final NavigationChannel _channel;
  final Duration retryDelay;
  final Logger _logger;
  late final StreamController<PositionFix> _controller;
  StreamSubscription<pb.PositionFix>? _subscription;
  Timer? _retry;

  /// Logged once per outage, not on every retry.
  bool _broken = false;

  @override
  Stream<PositionFix> get positions => _controller.stream;

  void _connect() {
    _retry = null;
    _subscription = _channel.stub
        .streamPositions(pb.Empty())
        .listen(
          _onFix,
          onError: _onBroken,
          onDone: () => _onBroken('stream closed'),
          cancelOnError: true,
        );
  }

  void _onFix(pb.PositionFix fix) {
    if (_broken) {
      _broken = false;
      _logger.info('Position stream back');
    }
    final position = positionFromProto(fix);
    if (position != null) {
      _controller.add(position);
    }
  }

  void _onBroken(Object reason) {
    _subscription = null;
    if (!_controller.hasListener) {
      return;
    }
    if (!_broken) {
      _broken = true;
      _logger.warning('Position stream lost, retrying: $reason');
    }
    _retry ??= Timer(retryDelay, () async {
      await _channel.reconnect();
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

  Future<void> dispose() async {
    await _disconnect();
    await _controller.close();
  }
}

/// The calls that are not part of the library's interfaces.
class NavigationStatusClient {
  NavigationStatusClient(this._channel);

  final NavigationChannel _channel;

  Future<pb.NavigationStatus> status() => _channel.stub.getNavigationStatus(
    pb.Empty(),
    options: CallOptions(timeout: const Duration(seconds: 2)),
  );

  /// The running replay's route, map-matched by the backend.
  Future<RoutingResult> replayRoute(String language) async {
    try {
      final route = await _channel.stub.getReplayRoute(
        pb.GetReplayRouteRequest(language: language),
        options: CallOptions(timeout: _callTimeout),
      );
      return routeFromProto(route);
    } catch (error) {
      throw navigationFailureFrom(error);
    }
  }
}
