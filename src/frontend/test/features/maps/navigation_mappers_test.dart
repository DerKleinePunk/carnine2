import 'package:carnine_frontend/features/maps/data/navigation_mappers.dart';
import 'package:carnine_frontend/features/maps/domain/navigation_failure.dart';
import 'package:carnine_frontend/features/maps/presentation/widgets/maneuver_icon.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart' as pb;
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

void main() {
  group('routeFromProto', () {
    test('converts SI units to the library model', () {
      final route = routeFromProto(
        pb.Route(
          geometry: [
            pb.LatLon(latitude: 50, longitude: 9),
            pb.LatLon(latitude: 50.1, longitude: 9.1),
          ],
          distanceMeters: 12345,
          durationSeconds: 600.6,
          maneuvers: [
            pb.Maneuver(
              instruction: 'Rechts abbiegen.',
              lengthMeters: 450,
              timeSeconds: 30.4,
              type: 10,
              beginShapeIndex: 1,
              streetNames: ['Lindenallee'],
            ),
          ],
        ),
      );

      expect(route.geometry, hasLength(2));
      expect(route.geometry[1].lon, 9.1);
      expect(route.distanceMeters, 12345);
      expect(route.durationSeconds, 601);
      final maneuver = route.maneuvers.single;
      expect(maneuver.lengthKm, closeTo(0.45, 1e-9));
      expect(maneuver.timeSeconds, 30);
      expect(maneuver.type, 10);
      expect(maneuver.beginShapeIndex, 1);
      expect(maneuver.streetNames, ['Lindenallee']);
    });
  });

  group('positionFromProto', () {
    test('passes only real fixes on, optional fields stay null', () {
      final noFix = pb.PositionFix(fixState: pb.FixState.FIX_STATE_NO_FIX);
      expect(positionFromProto(noFix), isNull);

      final bare = positionFromProto(
        pb.PositionFix(
          fixState: pb.FixState.FIX_STATE_FIX,
          location: pb.LatLon(latitude: 50.4, longitude: 9.36),
        ),
      );
      expect(bare?.position.latitude, 50.4);
      expect(bare?.headingDegrees, isNull);
      expect(bare?.speedMps, isNull);
      expect(bare?.timestampUtc, isNull);
    });

    test('heading, speed and GPS time are carried over', () {
      final fix = positionFromProto(
        pb.PositionFix(
          fixState: pb.FixState.FIX_STATE_FIX,
          location: pb.LatLon(latitude: 50.4, longitude: 9.36),
          headingDegrees: 87.5,
          speedMps: 13.9,
          timestampUtcMs: Int64(1758700000000),
        ),
      );
      expect(fix?.headingDegrees, 87.5);
      expect(fix?.speedMps, 13.9);
      expect(fix?.timestampUtc?.isUtc, isTrue);
      expect(fix?.timestampUtc?.millisecondsSinceEpoch, 1758700000000);
    });
  });

  test('placeFromProto maps the place type to the library string', () {
    final place = placeFromProto(
      pb.Place(
        name: 'Alsfeld',
        location: pb.LatLon(latitude: 50.75, longitude: 9.27),
        zoom: 12,
        type: pb.PlaceType.PLACE_TYPE_TRANSPORTATION_NAME,
      ),
    );
    expect(place.type, 'transportation_name');
    expect(place.detail, isNull);
    expect(place.zoom, 12);
  });

  group('navigationFailureFrom', () {
    test('ADR-021 status codes to failure kinds', () {
      expect(
        navigationFailureFrom(const GrpcError.unavailable()).kind,
        NavigationFailureKind.offline,
      );
      expect(
        navigationFailureFrom(const GrpcError.notFound('no route')).kind,
        NavigationFailureKind.notFound,
      );
      expect(
        navigationFailureFrom(const GrpcError.failedPrecondition()).kind,
        NavigationFailureKind.noPosition,
      );
      expect(
        navigationFailureFrom(const GrpcError.internal()).kind,
        NavigationFailureKind.unknown,
      );
    });

    test('transport errors count as offline', () {
      expect(
        navigationFailureFrom(Exception('socket')).kind,
        NavigationFailureKind.offline,
      );
    });
  });

  group('turn card helpers', () {
    test('formatDistance rounds metres to 10, km to one decimal', () {
      expect(formatDistance(447), ('450', 'm'));
      expect(formatDistance(999), ('1000', 'm'));
      expect(formatDistance(18420), ('18.4', 'km'));
    });

    test('maneuverIcon covers turns and destination', () {
      expect(maneuverIcon(10), Icons.turn_right);
      expect(maneuverIcon(15), Icons.turn_left);
      expect(maneuverIcon(4), Icons.flag);
      expect(maneuverIcon(null), Icons.straight);
    });
  });
}
