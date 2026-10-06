import 'dart:io';

import 'package:carnine_frontend/features/maps/data/grpc_navigation_adapters.dart';
import 'package:carnine_frontend/features/maps/data/navigation_channel.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart' as pb;
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:local_map/local_map.dart';

/// Stand-in for the backend: remembers every route request and answers
/// with a two-point route.
class _FakeNavigationService extends pb.NavigationServiceBase {
  final requests = <pb.ComputeRouteRequest>[];

  @override
  Future<pb.Route> computeRoute(
    ServiceCall call,
    pb.ComputeRouteRequest request,
  ) async {
    requests.add(request);
    return pb.Route(
      routeId: 'route-1',
      geometry: [
        pb.LatLon(latitude: 50.75, longitude: 9.27),
        pb.LatLon(latitude: 50.76, longitude: 9.28),
      ],
      distanceMeters: 1300,
      durationSeconds: 90,
    );
  }

  @override
  Future<pb.SearchPlacesResponse> searchPlaces(
    ServiceCall call,
    pb.SearchPlacesRequest request,
  ) => throw GrpcError.unimplemented();

  @override
  Stream<pb.PositionFix> streamPositions(ServiceCall call, pb.Empty request) =>
      const Stream.empty();

  @override
  Future<pb.NavigationStatus> getNavigationStatus(
    ServiceCall call,
    pb.Empty request,
  ) async => pb.NavigationStatus();

  @override
  Future<pb.ServiceVersion> getServiceVersion(
    ServiceCall call,
    pb.Empty request,
  ) async => pb.ServiceVersion();

  @override
  Future<pb.LocationName> getLocationName(
    ServiceCall call,
    pb.GetLocationNameRequest request,
  ) => throw GrpcError.unimplemented();

  @override
  Future<pb.Route> getReplayRoute(
    ServiceCall call,
    pb.GetReplayRouteRequest request,
  ) => throw GrpcError.unimplemented();

  @override
  Future<pb.NavigationStatus> setTrackRecording(
    ServiceCall call,
    pb.SetTrackRecordingRequest request,
  ) => throw GrpcError.unimplemented();
}

void main() {
  late _FakeNavigationService service;
  late Server server;
  late NavigationChannel channel;
  late GrpcRoutingProvider provider;

  setUp(() async {
    service = _FakeNavigationService();
    server = Server.create(services: [service]);
    await server.serve(address: InternetAddress.loopbackIPv4, port: 0);
    final port = server.port!;
    channel = NavigationChannel(
      channelFactory: () => ClientChannel(
        InternetAddress.loopbackIPv4,
        port: port,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      ),
    );
    provider = GrpcRoutingProvider(channel, language: () => 'de-DE');
  });

  tearDown(() async {
    await channel.shutdown();
    await server.shutdown();
  });

  test('a reroute while driving sends the course at the start', () async {
    await provider.route(
      end: const LatLng(50.76, 9.28),
      startHeadingDegrees: 184,
    );

    final request = service.requests.single;
    expect(request.hasOrigin(), isFalse, reason: 'the backend uses its fix');
    expect(request.hasOriginHeadingDegrees(), isTrue);
    expect(request.originHeadingDegrees, 184);
  });

  test('without a course from the library none goes out', () async {
    await provider.route(
      start: const LatLng(50.75, 9.27),
      end: const LatLng(50.76, 9.28),
    );

    final request = service.requests.single;
    expect(request.hasOrigin(), isTrue);
    expect(request.hasOriginHeadingDegrees(), isFalse);
  });
}
