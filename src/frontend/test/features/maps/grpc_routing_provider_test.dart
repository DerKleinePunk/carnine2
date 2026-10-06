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
  final prepared = <List<String>>[];
  final announced = <pb.AnnounceRequest>[];

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
  @override
  Future<pb.Empty> prepareAnnouncements(
    ServiceCall call,
    pb.PrepareAnnouncementsRequest request,
  ) async {
    prepared.add(request.texts.toList());
    return pb.Empty();
  }

  @override
  Future<pb.Empty> announce(
    ServiceCall call,
    pb.AnnounceRequest request,
  ) async {
    announced.add(request);
    return pb.Empty();
  }

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

  test('announcements reach the backend with their priority', () async {
    final announcer = GrpcAnnouncer(channel);
    await announcer.handle(
      const AnnouncementPrepare([
        'In 300 Metern rechts abbiegen.',
        'Die Route wird neu berechnet.',
      ]),
    );
    await announcer.handle(
      const Announcement(
        'In 300 Metern rechts abbiegen.',
        AnnouncementPriority.maneuver,
      ),
    );
    await announcer.handle(
      const Announcement(
        'Die Route wird neu berechnet.',
        AnnouncementPriority.info,
      ),
    );

    expect(service.prepared, [
      ['In 300 Metern rechts abbiegen.', 'Die Route wird neu berechnet.'],
    ]);
    expect(service.announced.map((a) => a.text), [
      'In 300 Metern rechts abbiegen.',
      'Die Route wird neu berechnet.',
    ]);
    expect(service.announced.map((a) => a.priority), [
      pb.AnnouncementPriority.ANNOUNCEMENT_PRIORITY_MANEUVER,
      pb.AnnouncementPriority.ANNOUNCEMENT_PRIORITY_INFO,
    ]);
  });

  test('announcements stay silent unless the display is German', () async {
    var language = 'en';
    final announcer = GrpcAnnouncer(channel, language: () => language);
    await announcer.handle(
      const AnnouncementPrepare(['In 300 Metern Turn right.']),
    );
    await announcer.handle(
      const Announcement('Turn right.', AnnouncementPriority.maneuver),
    );
    expect(service.prepared, isEmpty);
    expect(service.announced, isEmpty);

    language = 'de';
    await announcer.handle(
      const Announcement('Rechts abbiegen.', AnnouncementPriority.maneuver),
    );
    expect(service.announced.map((a) => a.text), ['Rechts abbiegen.']);
  });

  test('German is recognized in every spelling of the tag', () {
    expect(GrpcAnnouncer.speaksGerman('de'), isTrue);
    expect(GrpcAnnouncer.speaksGerman('de-DE'), isTrue);
    expect(GrpcAnnouncer.speaksGerman('de_AT'), isTrue);
    expect(GrpcAnnouncer.speaksGerman('DE'), isTrue);
    expect(GrpcAnnouncer.speaksGerman('en'), isFalse);
    expect(GrpcAnnouncer.speaksGerman('da'), isFalse);
    expect(GrpcAnnouncer.speaksGerman(''), isFalse);
  });

  test('a backend that is gone does not break the map', () async {
    await server.shutdown();
    await GrpcAnnouncer(channel).handle(
      const Announcement(
        'Jetzt links abbiegen.',
        AnnouncementPriority.maneuver,
      ),
    );
  });
}
