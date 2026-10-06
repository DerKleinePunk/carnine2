import 'dart:async';
import 'dart:io';

import 'package:carnine_frontend/features/maps/data/navigation_channel.dart';
import 'package:carnine_frontend/features/maps/presentation/maps_controller.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart' as pb;
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

/// Stand-in for the backend: remembers every search request and streams
/// whatever fixes the test adds to [positions].
class _FakeNavigationService extends pb.NavigationServiceBase {
  final requests = <pb.SearchPlacesRequest>[];
  final positions = StreamController<pb.PositionFix>.broadcast();

  @override
  Future<pb.SearchPlacesResponse> searchPlaces(
    ServiceCall call,
    pb.SearchPlacesRequest request,
  ) async {
    requests.add(request);
    return pb.SearchPlacesResponse();
  }

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
  ) => throw GrpcError.unimplemented();

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
  late _FakeNavigationService service;
  late Server server;
  late MapsController controller;

  setUp(() async {
    service = _FakeNavigationService();
    server = Server.create(services: [service]);
    await server.serve(address: InternetAddress.loopbackIPv4, port: 0);
    final port = server.port!;
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
    );
  });

  tearDown(() async {
    controller.dispose();
    await service.positions.close();
    await server.shutdown();
  });

  test('without a fix the search goes out without a position', () async {
    await controller.search('Hauptstraße');

    expect(service.requests, hasLength(1));
    expect(service.requests.single.query, 'Hauptstraße');
    expect(service.requests.single.hasNear(), isFalse);
  });

  test('with a fix the search sends the current position (#74)', () async {
    // The position stream is subscribed when the controller is built; wait
    // until the fake server has its listener before sending the fix.
    while (!service.positions.hasListener) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    service.positions.add(
      pb.PositionFix(
        fixState: pb.FixState.FIX_STATE_FIX,
        location: pb.LatLon(latitude: 50.75, longitude: 9.27),
      ),
    );
    while (controller.map.position == null) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    await controller.search('Hauptstraße');

    final near = service.requests.single.near;
    expect(service.requests.single.hasNear(), isTrue);
    expect(near.latitude, 50.75);
    expect(near.longitude, 9.27);
  });
}
