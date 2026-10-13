import 'dart:async';
import 'dart:io';

import 'package:carnine_frontend/features/maps/data/navigation_channel.dart';
import 'package:carnine_frontend/features/maps/presentation/maps_controller.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart' as pb;
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:local_map/local_map.dart';
import 'package:logging/logging.dart';

/// Stand-in for the backend with a replay: the test sets [status] and
/// [destinationName], the service counts how often the route is fetched.
class _FakeNavigationService extends pb.NavigationServiceBase {
  pb.NavigationStatus status = pb.NavigationStatus();
  String destinationName = 'Kunsthalle Montez';
  int replayRouteRequests = 0;
  final positions = StreamController<pb.PositionFix>.broadcast();

  /// A replay in round [lap]; the trade fair mode when [demo] is set.
  void replay({required int lap, bool demo = true}) {
    status = pb.NavigationStatus(
      positionSource: pb.PositionSourceKind.POSITION_SOURCE_REPLAY,
      replayLap: lap,
      demoMode: demo,
    );
  }

  @override
  Future<pb.NavigationStatus> getNavigationStatus(
    ServiceCall call,
    pb.Empty request,
  ) async => status;

  @override
  Future<pb.Route> getReplayRoute(
    ServiceCall call,
    pb.GetReplayRouteRequest request,
  ) async {
    replayRouteRequests++;
    return pb.Route(
      distanceMeters: 1000,
      durationSeconds: 60,
      geometry: [
        pb.LatLon(latitude: 50.10, longitude: 8.66),
        pb.LatLon(latitude: 50.11, longitude: 8.67),
      ],
      destinationName: destinationName,
    );
  }

  @override
  Stream<pb.PositionFix> streamPositions(ServiceCall call, pb.Empty request) =>
      positions.stream;

  @override
  Future<pb.SearchPlacesResponse> searchPlaces(
    ServiceCall call,
    pb.SearchPlacesRequest request,
  ) async => pb.SearchPlacesResponse();

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
  Future<pb.Empty> announce(
    ServiceCall call,
    pb.AnnounceRequest request,
  ) async => pb.Empty();

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

  /// Asks the backend for its status and waits until the route fetch that may
  /// follow has finished.
  Future<void> poll() async {
    await controller.refreshStatus();
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  RoutingResult ownRoute() => RoutingResult(
    geometry: const [
      RoutingPoint(lat: 50.2, lon: 8.7),
      RoutingPoint(lat: 50.3, lon: 8.8),
    ],
    distanceMeters: 500,
    durationSeconds: 30,
    maneuvers: const [],
  );

  group('the round of the replay (#126)', () {
    test(
      'the replay route comes with the name of its destination (#127)',
      () async {
        service.replay(lap: 1);

        await poll();

        expect(controller.map.route, isNotNull);
        expect(controller.map.followPosition, isTrue);
        expect(controller.map.headingUp, isTrue);
        expect(controller.replayDestinationName, 'Kunsthalle Montez');
      },
    );

    test('a route without a name shows none', () async {
      service
        ..destinationName = ''
        ..replay(lap: 1);

      await poll();

      expect(controller.map.route, isNotNull);
      expect(controller.replayDestinationName, isNull);
    });

    test('Abbrechen holds until the end of the round, then the next round '
        'brings the route back', () async {
      service.replay(lap: 1);
      await poll();
      expect(service.replayRouteRequests, 1);

      controller.cancelRoute();
      expect(controller.map.route, isNull);
      expect(controller.replayDestinationName, isNull);

      // Still round 1: nothing comes back, nothing is asked for.
      await poll();
      await poll();
      expect(controller.map.route, isNull);
      expect(service.replayRouteRequests, 1);

      // The tour starts again.
      service.replay(lap: 2);
      await poll();

      expect(controller.map.route, isNotNull);
      expect(service.replayRouteRequests, 2);
      expect(controller.map.followPosition, isTrue);
      expect(controller.map.headingUp, isTrue);
      expect(controller.replayDestinationName, 'Kunsthalle Montez');
    });

    test('a new round does not touch the route that is running', () async {
      service.replay(lap: 1);
      await poll();
      final route = controller.map.route;

      service.replay(lap: 2);
      await poll();

      expect(controller.map.route, same(route));
      expect(service.replayRouteRequests, 1);
    });

    test('a round number that falls means the backend started over: the '
        'old route goes, the new one is fetched', () async {
      service.replay(lap: 5);
      await poll();
      final oldRoute = controller.map.route;
      expect(service.replayRouteRequests, 1);

      service
        ..replay(lap: 1)
        ..destinationName = 'Neues Ziel';
      await poll();

      expect(service.replayRouteRequests, 2);
      expect(controller.map.route, isNotNull);
      expect(controller.map.route, isNot(same(oldRoute)));
      expect(controller.replayDestinationName, 'Neues Ziel');
    });

    test('after Abbrechen a backend that started over brings the route back '
        'as well', () async {
      service.replay(lap: 5);
      await poll();
      controller.cancelRoute();

      service.replay(lap: 1);
      await poll();

      expect(controller.map.route, isNotNull);
      expect(service.replayRouteRequests, 2);
    });

    test(
      'a route the user chose is not dropped when the round falls',
      () async {
        service.replay(lap: 5);
        await poll();
        controller.cancelRoute();
        final own = ownRoute();
        controller.map.setRoute(own);

        service.replay(lap: 1);
        await poll();

        expect(controller.map.route, same(own));
        expect(controller.replayDestinationName, isNull);
      },
    );

    test('without a replay nothing is held back', () async {
      service.replay(lap: 1);
      await poll();
      controller.cancelRoute();

      service.status = pb.NavigationStatus(
        positionSource: pb.PositionSourceKind.POSITION_SOURCE_NONE,
      );
      await poll();
      service.replay(lap: 1);
      await poll();

      expect(controller.map.route, isNotNull);
    });
  });

  group('trade fair mode (#128)', () {
    test('demoMode follows the status of the backend', () async {
      expect(controller.demoMode, isFalse);

      service.replay(lap: 1);
      await poll();
      expect(controller.demoMode, isTrue);

      service.replay(lap: 1, demo: false);
      await poll();
      expect(controller.demoMode, isFalse);
    });
  });

  group('the zoom in the log (#130)', () {
    late List<String> lines;
    late StreamSubscription<LogRecord> subscription;

    setUp(() {
      lines = [];
      Logger.root.level = Level.ALL;
      subscription = Logger.root.onRecord
          .where((record) => record.message.startsWith('[map] Zoom'))
          .listen((record) => lines.add(record.message));
    });

    tearDown(() => subscription.cancel());

    Future<void> zoomTo(double zoom) async {
      controller.map.reportZoom(zoom);
      await Future<void>.delayed(Duration.zero);
    }

    test('one line for every whole level, with the exact value', () async {
      await zoomTo(13);
      await zoomTo(15.7);
      await zoomTo(16);

      expect(lines, ['[map] Zoom 13 (13.0)', '[map] Zoom 16 (15.7)']);
    });

    test('small changes inside a level write nothing', () async {
      await zoomTo(15.6);
      lines.clear();

      await zoomTo(15.7);
      await zoomTo(15.9);
      await zoomTo(16.2);
      await zoomTo(15.51);

      expect(lines, isEmpty);
    });

    test('going to another level and back writes both', () async {
      await zoomTo(16);
      lines.clear();

      await zoomTo(14.2);
      await zoomTo(16);

      expect(lines, ['[map] Zoom 14 (14.2)', '[map] Zoom 16 (16.0)']);
    });
  });
}
