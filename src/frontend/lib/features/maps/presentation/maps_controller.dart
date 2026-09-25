import 'dart:async';
import 'dart:io';

import 'package:carnine_frontend/features/maps/data/grpc_navigation_adapters.dart';
import 'package:carnine_frontend/features/maps/data/navigation_channel.dart';
import 'package:carnine_frontend/features/maps/domain/navigation_failure.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart' as pb;
import 'package:flutter/foundation.dart';
import 'package:local_map/local_map.dart';
import 'package:logging/logging.dart';

/// State of the maps page: the map library's controller wired to the
/// backend's `NavigationService` (ADR-021), plus destination search.
///
/// Owned by `DashboardScreen`, like `MediaController`, so route and position
/// survive switching sidebar sections. No routing or progress logic here -
/// that is the backend's and the library's job.
class MapsController extends ChangeNotifier {
  MapsController({
    NavigationChannel? channel,
    LanguageTag? language,
    this.statusInterval = const Duration(seconds: 3),
    Logger? logger,
  }) : _channel = channel ?? NavigationChannel(),
       _logger = logger ?? Logger('MapsController') {
    _language = language ?? () => 'de-DE';
    _routing = GrpcRoutingProvider(_channel, language: () => _language());
    _positions = GrpcPositionSource(_channel);
    _search = GrpcPlaceSearch(_channel);
    _statusClient = NavigationStatusClient(_channel);
    map = LocalMapController(
      routingProvider: _routing,
      positionSource: _positions,
    );
    unawaited(_pollStatus());
    _statusTimer = Timer.periodic(statusInterval, (_) => _pollStatus());
  }

  /// Environment override for the tile file, like the other `CARNINE_*`
  /// paths; the default is where the image puts the map data.
  static String tilesPath() =>
      Platform.environment['CARNINE_MAP_TILES'] ??
      '/var/lib/carnine/maps/map.mbtiles';

  final Duration statusInterval;
  final NavigationChannel _channel;
  final Logger _logger;
  late final LanguageTag _language;
  late final GrpcRoutingProvider _routing;
  late final GrpcPositionSource _positions;
  late final GrpcPlaceSearch _search;
  late final NavigationStatusClient _statusClient;
  late final LocalMapController map;
  Timer? _statusTimer;
  bool _disposed = false;

  pb.NavigationStatus? _status;
  bool _replayRouteLoading = false;
  bool _replayDismissed = false;
  List<GeocoderResult> _results = const [];
  bool _searching = false;
  bool _queried = false;
  NavigationFailure? _searchFailure;
  int _searchRequest = 0;

  /// Last answer of `GetNavigationStatus`, `null` while the backend is down.
  pb.NavigationStatus? get status => _status;
  bool get backendReachable => _status != null;
  List<GeocoderResult> get results => _results;
  bool get searching => _searching;
  NavigationFailure? get searchFailure => _searchFailure;

  /// A finished search without hits, for a "no results" line.
  bool get noResults =>
      _queried && !_searching && _results.isEmpty && _searchFailure == null;

  /// Why the last route failed, `null` if it did not.
  NavigationFailureKind? get routeFailure =>
      map.routingError == null ? null : _routing.lastFailure?.kind;

  /// Follow the position with heading up - the compass button's state.
  bool get navigationMode => map.followPosition && map.headingUp;

  /// Compass button: on = follow + heading up, off = north up.
  void toggleNavigationMode() {
    if (navigationMode) {
      map.headingUp = false;
    } else {
      map.followPosition = true;
      map.headingUp = true;
    }
    notifyListeners();
  }

  Future<void> search(String query) async {
    final request = ++_searchRequest;
    _queried = query.trim().isNotEmpty;
    if (!_queried) {
      _setResults(const [], null);
      return;
    }
    _searching = true;
    notifyListeners();
    try {
      final found = await _search.searchPlaces(
        query,
        near: map.position?.position,
      );
      if (request == _searchRequest) _setResults(found, null);
    } on NavigationFailure catch (failure) {
      if (request == _searchRequest) _setResults(const [], failure);
    }
  }

  void _setResults(List<GeocoderResult> results, NavigationFailure? failure) {
    if (_disposed) return;
    _results = results;
    _searchFailure = failure;
    _searching = false;
    notifyListeners();
  }

  /// Route from the current position to [place].
  Future<void> selectDestination(GeocoderResult place) async {
    _searchRequest++;
    _queried = false;
    _setResults(const [], null);
    await map.setDestination(place);
  }

  /// Cancel button. A replay route stays away until the source changes, so
  /// the demo does not come back the second after someone cancelled it.
  void cancelRoute() {
    map.setRoute(null);
    _replayDismissed = true;
    notifyListeners();
  }

  Future<void> _pollStatus() async {
    try {
      final status = await _statusClient.status();
      if (_disposed) return;
      _onStatus(status);
    } catch (error) {
      if (_disposed || _status == null) return;
      _logger.warning('Navigation status unavailable: $error');
      _status = null;
      notifyListeners();
    }
  }

  void _onStatus(pb.NavigationStatus status) {
    final isReplay =
        status.positionSource == pb.PositionSourceKind.POSITION_SOURCE_REPLAY;
    if (!isReplay) _replayDismissed = false;
    _status = status;
    notifyListeners();
    if (isReplay && map.route == null && !_replayDismissed) {
      unawaited(_loadReplayRoute());
    }
  }

  /// Trade fair: the replay's own route, map-matched in the backend, so
  /// arrow and line come from the same recording. Starts navigation mode.
  Future<void> _loadReplayRoute() async {
    if (_replayRouteLoading) return;
    _replayRouteLoading = true;
    try {
      final route = await _statusClient.replayRoute(_language());
      if (_disposed || map.route != null) return;
      map.setRoute(route);
      map.followPosition = true;
      map.headingUp = true;
      notifyListeners();
    } on NavigationFailure catch (failure) {
      _logger.info('No replay route yet: ${failure.kind} ${failure.message}');
    } finally {
      _replayRouteLoading = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _statusTimer?.cancel();
    map.dispose();
    unawaited(_positions.dispose());
    unawaited(_channel.shutdown());
    super.dispose();
  }
}
