import 'package:local_map/local_map.dart';

/// Why a navigation call failed, independent of the transport.
enum NavigationFailureKind {
  /// Backend or router not reachable.
  offline,

  /// No route between the points, or no replay running.
  notFound,

  /// No origin given and no GPS fix in the backend.
  noPosition,

  /// Anything else; details only in the log.
  unknown,
}

/// A [RoutingException] that also carries the failure kind, so the page can
/// show a localized message instead of the backend's text.
class NavigationFailure extends RoutingException {
  const NavigationFailure(this.kind, super.message);

  final NavigationFailureKind kind;
}
