import 'dart:async';
import 'dart:io';

import 'package:carnine_frontend/features/maps/data/navigation_channel.dart';
import 'package:carnine_frontend/features/maps/presentation/maps_controller.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart' as pb;
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:local_map/local_map.dart';

/// Stand-in for the internet: counts every request for traffic.
class _CountingTraffic implements TrafficProvider {
  int requests = 0;

  @override
  Future<TrafficReport> incidentsAlong(RoutingResult route) async {
    requests++;
    return const TrafficReport(incidents: [], sources: []);
  }
}

/// Stand-in for the backend: quiet, nothing but what the controller asks for
/// when it starts.
class _QuietNavigationService extends pb.NavigationServiceBase {
  final positions = StreamController<pb.PositionFix>.broadcast();

  @override
  Stream<pb.PositionFix> streamPositions(ServiceCall call, pb.Empty request) =>
      positions.stream;

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
  ) async => pb.LocationName();

  @override
  Future<pb.SearchPlacesResponse> searchPlaces(
    ServiceCall call,
    pb.SearchPlacesRequest request,
  ) async => pb.SearchPlacesResponse();

  @override
  Future<pb.Route> computeRoute(
    ServiceCall call,
    pb.ComputeRouteRequest request,
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

  @override
  Future<pb.Empty> prepareAnnouncements(
    ServiceCall call,
    pb.PrepareAnnouncementsRequest request,
  ) async => pb.Empty();

  @override
  Future<pb.Empty> announce(ServiceCall call, pb.AnnounceRequest request) =>
      throw GrpcError.unimplemented();

  @override
  Future<pb.VoiceSettings> getVoiceSettings(
    ServiceCall call,
    pb.Empty request,
  ) => throw GrpcError.unimplemented();

  @override
  Future<pb.VoiceSettings> setVoiceSettings(
    ServiceCall call,
    pb.SetVoiceSettingsRequest request,
  ) => throw GrpcError.unimplemented();
}

void main() {
  late _QuietNavigationService service;
  late Server server;
  late _CountingTraffic traffic;
  late MapsController controller;

  setUp(() async {
    service = _QuietNavigationService();
    server = Server.create(services: [service]);
    await server.serve(address: InternetAddress.loopbackIPv4, port: 0);
    final port = server.port!;
    traffic = _CountingTraffic();
    controller = MapsController(
      channel: NavigationChannel(
        channelFactory: () => ClientChannel(
          InternetAddress.loopbackIPv4,
          port: port,
          options: const ChannelOptions(
            credentials: ChannelCredentials.insecure(),
          ),
        ),
      ),
      statusInterval: const Duration(hours: 1),
      trafficProvider: traffic,
    );
  });

  tearDown(() async {
    controller.dispose();
    await service.positions.close();
    await server.shutdown();
  });

  /// A route on the A 3, the kind of road traffic is fetched for.
  RoutingResult route() => RoutingResult(
    geometry: const [
      RoutingPoint(lat: 50.05, lon: 8.57),
      RoutingPoint(lat: 49.97, lon: 9.15),
    ],
    distanceMeters: 42000,
    durationSeconds: 1500,
    maneuvers: const [],
  );

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('traffic is off when the map starts', () {
    expect(controller.trafficEnabled, isFalse);
    expect(controller.map.trafficEnabled, isFalse);
  });

  test('off: a route on the map asks the internet nothing', () async {
    controller.map.setRoute(route());
    await settle();
    expect(traffic.requests, 0);
  });

  test('switched on with a route it asks once, switched off no more', () async {
    controller.map.setRoute(route());
    await settle();
    expect(traffic.requests, 0);

    controller.setTrafficEnabled(true);
    await settle();
    expect(controller.trafficEnabled, isTrue);
    expect(traffic.requests, 1);

    controller.setTrafficEnabled(false);
    controller.map.setRoute(route());
    await settle();
    expect(controller.trafficEnabled, isFalse);
    expect(traffic.requests, 1, reason: 'a new route while off asks nothing');
  });
}
