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
    this.replayRetryDelays = defaultReplayRetryDelays,
    DateTime Function()? now,
    Logger? logger,
  }) : _channel = channel ?? NavigationChannel(),
       _now = now ?? DateTime.now,
       _logger = logger ?? Logger('MapsController') {
    _language = language ?? () => 'de-DE';
    _routing = GrpcRoutingProvider(_channel, language: () => _language());
    _positions = GrpcPositionSource(_channel);
    _search = GrpcPlaceSearch(_channel);
    _statusClient = NavigationStatusClient(_channel);
    map = LocalMapController(
      routingProvider: _routing,
      positionSource: _positions,
      reverseGeocoder: GrpcReverseGeocoder(_channel),
    );
    _loggedZoomStep = map.zoom.value.round();
    map.zoom.addListener(_logZoom);
    _announcer = GrpcAnnouncer(_channel, language: () => _language());
    // One after the other, so a Prepare reaches the backend before the
    // Announce of one of its sentences.
    _announcements = map.announcements.listen((event) {
      _announced = _announced.then((_) => _announcer.handle(event));
    });
    unawaited(_pollStatus());
    _statusTimer = Timer.periodic(statusInterval, (_) => _pollStatus());
  }

  /// Environment override for the tile file, like the other `CARNINE_*`
  /// paths; the default is where the image puts the map data.
  static String tilesPath() =>
      Platform.environment['CARNINE_MAP_TILES'] ??
      '/var/lib/carnine/maps/map.mbtiles';

  /// How long to wait before fetching the replay route again after it failed:
  /// the first pause, the second, ... the last one holds from then on (#100).
  /// The status is asked every [statusInterval]; a pause shorter than that
  /// means "at the next one".
  static const List<Duration> defaultReplayRetryDelays = [
    Duration(seconds: 3),
    Duration(seconds: 6),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  final Duration statusInterval;
  final List<Duration> replayRetryDelays;
  final DateTime Function() _now;
  final NavigationChannel _channel;
  final Logger _logger;
  late final LanguageTag _language;
  late final GrpcRoutingProvider _routing;
  late final GrpcPositionSource _positions;
  late final GrpcPlaceSearch _search;
  late final NavigationStatusClient _statusClient;
  late final LocalMapController map;
  late final GrpcAnnouncer _announcer;
  late final StreamSubscription<AnnouncementEvent> _announcements;
  Future<void> _announced = Future.value();
  Timer? _statusTimer;
  bool _disposed = false;

  pb.NavigationStatus? _status;
  bool _replayRouteLoading = false;
  bool _replayDismissed = false;

  /// The round of the replay in which "Abbrechen" was pressed: the replay
  /// route stays away until the round is over (#126).
  int? _dismissedLap;

  /// The round the last status reported, `null` without a replay.
  int? _seenLap;

  /// Whether the route on the map is the replay's own, not one the user
  /// chose - only that one is dropped when the backend starts over.
  bool _replayRouteShown = false;
  String? _replayDestinationName;
  int _loggedZoomStep = 0;

  /// Fetching the replay route failed this often in a row; the next try waits
  /// until [_replayRetryAt] (#100).
  int _replayFailures = 0;
  DateTime? _replayRetryAt;

  /// The reason that was logged last, so a reason that stays is logged once.
  String? _loggedReplayProblem;
  List<GeocoderResult> _results = const [];
  bool _searching = false;
  bool _queried = false;
  NavigationFailure? _searchFailure;
  int _searchRequest = 0;

  /// Last answer of `GetNavigationStatus`, `null` while the backend is down.
  pb.NavigationStatus? get status => _status;

  /// Trade fair mode (`[navigation] demo_mode`): the device drives the tour
  /// on its own and returns to the map when nobody touches it (#128). Unknown
  /// while the backend is down.
  bool get demoMode => _status?.demoMode ?? false;

  /// The name of the end point while the replay's route is on the map, for
  /// the search field (#127); `null` for a route the user chose.
  String? get replayDestinationName => _replayDestinationName;
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
    _replayRouteShown = false;
    _replayDestinationName = null;
    _setResults(const [], null);
    await map.setDestination(place);
  }

  /// Cancel button. A replay route stays away until the round is over, so
  /// the demo does not come back the second after someone cancelled it; the
  /// next round brings it back (#126).
  void cancelRoute() {
    map.setRoute(null);
    _replayDismissed = true;
    _dismissedLap = _status?.replayLap;
    _replayRouteShown = false;
    _replayDestinationName = null;
    notifyListeners();
  }

  /// Asks the backend for its status now, instead of at the next tick.
  @visibleForTesting
  Future<void> refreshStatus() => _pollStatus();

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
    final lap = status.replayLap;
    final previousLap = _seenLap;
    _seenLap = isReplay ? lap : null;
    if (!isReplay || lap != previousLap) {
      // A new round, a restart or another source: what failed may work now.
      _resetReplayRetries();
    }
    if (!isReplay) {
      _replayDismissed = false;
      _dismissedLap = null;
    } else {
      // "Abbrechen" holds until the end of the round: a new one lifts it.
      if (_replayDismissed && lap != _dismissedLap) {
        _replayDismissed = false;
      }
      // The round counter fell: the backend started over (restarted, or the
      // trade fair mode was switched on), so the route on the map is an old
      // one. Drop it and fetch the new one.
      if (previousLap != null && lap < previousLap) {
        _replayDismissed = false;
        if (_replayRouteShown) {
          map.setRoute(null);
          _replayRouteShown = false;
          _replayDestinationName = null;
        }
      }
    }
    _status = status;
    notifyListeners();
    if (isReplay &&
        map.route == null &&
        !_replayDismissed &&
        !_waitingToRetryReplayRoute) {
      unawaited(_loadReplayRoute());
    }
  }

  bool get _waitingToRetryReplayRoute {
    final retryAt = _replayRetryAt;
    return retryAt != null && _now().isBefore(retryAt);
  }

  void _resetReplayRetries() {
    _replayFailures = 0;
    _replayRetryAt = null;
  }

  /// The route could not be fetched: wait longer each time, and say why only
  /// when the reason is a new one. Every 3 s the same line filled the log.
  void _replayRouteFailed(NavigationFailure failure) {
    _replayFailures++;
    final delays = replayRetryDelays;
    final delay = delays[(_replayFailures - 1).clamp(0, delays.length - 1)];
    _replayRetryAt = _now().add(delay);
    final problem = '${failure.kind.name}: ${failure.message}';
    if (problem != _loggedReplayProblem) {
      _loggedReplayProblem = problem;
      _logger.info(
        'No replay route yet: $problem (trying again in '
        '${delay.inSeconds} s, then less often)',
      );
    }
  }

  /// Trade fair: the replay's own route, map-matched in the backend, so
  /// arrow and line come from the same recording. Starts navigation mode.
  Future<void> _loadReplayRoute() async {
    if (_replayRouteLoading) return;
    _replayRouteLoading = true;
    try {
      final replay = await _statusClient.replayRoute(_language());
      if (_disposed || map.route != null) return;
      map.setRoute(replay.route);
      _resetReplayRetries();
      if (_loggedReplayProblem != null) {
        _loggedReplayProblem = null;
        _logger.info('Replay route loaded');
      }
      _replayRouteShown = true;
      _replayDestinationName = replay.destinationName.isEmpty
          ? null
          : replay.destinationName;
      map.followPosition = true;
      map.headingUp = true;
      notifyListeners();
    } on NavigationFailure catch (failure) {
      _replayRouteFailed(failure);
    } finally {
      _replayRouteLoading = false;
    }
  }

  /// One line when the whole zoom level changes, so a trade fair rehearsal or
  /// a long test shows how far in or out the map was (#130). Gestures move
  /// the zoom continuously; within one level nothing is written.
  void _logZoom() {
    final zoom = map.zoom.value;
    final step = zoom.round();
    if (step == _loggedZoomStep) return;
    _loggedZoomStep = step;
    _logger.info('[map] Zoom $step (${zoom.toStringAsFixed(1)})');
  }

  @override
  void dispose() {
    _disposed = true;
    map.zoom.removeListener(_logZoom);
    _statusTimer?.cancel();
    unawaited(_announcements.cancel());
    map.dispose();
    unawaited(_positions.dispose());
    unawaited(_channel.shutdown());
    super.dispose();
  }
}
