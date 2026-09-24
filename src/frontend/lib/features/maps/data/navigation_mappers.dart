import 'package:carnine_frontend/features/maps/domain/navigation_failure.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart' as pb;
import 'package:grpc/grpc.dart';
import 'package:local_map/local_map.dart';

/// Proto <-> local_map models. Pure functions, no logic beyond unit
/// conversion (ADR-021: SI units on the wire, the library keeps km for
/// maneuver lengths).

LatLng latLngFromProto(pb.LatLon value) =>
    LatLng(value.latitude, value.longitude);

pb.LatLon latLonToProto(LatLng value) =>
    pb.LatLon(latitude: value.latitude, longitude: value.longitude);

RoutingResult routeFromProto(pb.Route route) => RoutingResult(
  geometry: [
    for (final p in route.geometry)
      RoutingPoint(lat: p.latitude, lon: p.longitude),
  ],
  distanceMeters: route.distanceMeters,
  durationSeconds: route.durationSeconds.round(),
  maneuvers: [for (final m in route.maneuvers) _maneuverFromProto(m)],
);

RoutingManeuver _maneuverFromProto(pb.Maneuver m) => RoutingManeuver(
  instruction: m.instruction,
  lengthKm: m.lengthMeters / 1000,
  timeSeconds: m.timeSeconds.round(),
  type: m.type,
  beginShapeIndex: m.beginShapeIndex,
  streetNames: List.unmodifiable(m.streetNames),
);

/// `null` for fixes without a valid position (`FIX_STATE_NO_FIX`); the
/// library only gets real positions.
PositionFix? positionFromProto(pb.PositionFix fix) {
  if (fix.fixState != pb.FixState.FIX_STATE_FIX || !fix.hasLocation()) {
    return null;
  }
  return PositionFix(
    position: latLngFromProto(fix.location),
    headingDegrees: fix.hasHeadingDegrees() ? fix.headingDegrees : null,
    speedMps: fix.hasSpeedMps() ? fix.speedMps : null,
    accuracyMeters: fix.hasAccuracyMeters() ? fix.accuracyMeters : null,
    timestampUtc: fix.hasTimestampUtcMs()
        ? DateTime.fromMillisecondsSinceEpoch(
            fix.timestampUtcMs.toInt(),
            isUtc: true,
          )
        : null,
  );
}

GeocoderResult placeFromProto(pb.Place place) => GeocoderResult(
  name: place.name,
  location: latLngFromProto(place.location),
  zoom: place.zoom,
  type: _placeTypeName(place.type),
  detail: place.hasDetail() ? place.detail : null,
);

String _placeTypeName(pb.PlaceType type) => switch (type) {
  pb.PlaceType.PLACE_TYPE_POI => 'poi',
  pb.PlaceType.PLACE_TYPE_MOUNTAIN_PEAK => 'mountain_peak',
  pb.PlaceType.PLACE_TYPE_WATER_NAME => 'water_name',
  pb.PlaceType.PLACE_TYPE_TRANSPORTATION_NAME => 'transportation_name',
  _ => 'place',
};

/// ADR-021 status codes to a failure kind.
NavigationFailure navigationFailureFrom(Object error) {
  if (error is! GrpcError) {
    return NavigationFailure(NavigationFailureKind.offline, error.toString());
  }
  final message = error.message ?? error.codeName;
  final kind = switch (error.code) {
    StatusCode.unavailable => NavigationFailureKind.offline,
    StatusCode.notFound => NavigationFailureKind.notFound,
    StatusCode.failedPrecondition => NavigationFailureKind.noPosition,
    _ => NavigationFailureKind.unknown,
  };
  return NavigationFailure(kind, message);
}
