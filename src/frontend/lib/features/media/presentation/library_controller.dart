import 'dart:async';

import 'package:carnine_frontend/features/media/domain/media_backend_exception.dart';
import 'package:carnine_frontend/features/media/domain/media_repository.dart';
import 'package:carnine_frontend/features/media/domain/models/library_scan_event.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/presentation/models/media_view_state.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Presentation controller for the media library: search, results and
/// rescan progress.
///
/// Subscribes to `StreamLibraryEvents` for as long as the media section is
/// visible, so an automatic rescan triggered by a USB storage event (see
/// `src/backend/src/storage_events.rs`) refreshes the visible list without
/// user action.
class LibraryController extends ChangeNotifier {
  LibraryController({
    required MediaRepository repository,
    void Function(Object error)? onStreamFailure,
    Logger? logger,
  })  : _repository = repository,
        _onStreamFailure = onStreamFailure,
        _logger = logger ?? Logger('LibraryController');

  static const _debounceDuration = Duration(milliseconds: 300);
  static const _scanWatchdogDuration = Duration(seconds: 60);

  final MediaRepository _repository;
  final void Function(Object error)? _onStreamFailure;
  final Logger _logger;

  MediaViewState _state = const MediaViewState.loading();
  List<MediaLibraryTrack> _results = const [];
  String _query = '';
  Timer? _debounce;

  bool _isScanning = false;
  int _scanProcessed = 0;
  int _scanImported = 0;
  String? _scanFailedPath;
  Timer? _scanWatchdog;

  StreamSubscription<LibraryScanEvent>? _libraryEvents;

  MediaViewState get state => _state;
  List<MediaLibraryTrack> get results => _results;
  String get query => _query;
  bool get isScanning => _isScanning;
  int get scanProcessed => _scanProcessed;
  int get scanImported => _scanImported;
  String? get scanFailedPath => _scanFailedPath;

  /// Subscribes to the library event stream and loads the library. Safe to
  /// call again after [reconnect] tore the previous subscription down.
  Future<void> start() async {
    await _libraryEvents?.cancel();
    _libraryEvents = _repository.libraryEvents().listen(
          _onLibraryEvent,
          onError: _onStreamError,
        );
    await _load();
  }

  /// Re-subscribes to the library event stream and reloads the library
  /// after the underlying transport was rebuilt.
  Future<void> reconnect() => start();

  @override
  void dispose() {
    _debounce?.cancel();
    _scanWatchdog?.cancel();
    _libraryEvents?.cancel();
    super.dispose();
  }

  void onQueryChanged(String query) {
    _query = query;
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _search);
  }

  Future<void> retry() => _load();

  Future<void> rescan() async {
    if (_isScanning) {
      return;
    }

    // The backend runs the whole scan synchronously and only returns the
    // response stream once it is finished (see main.rs `rescan_media`), so
    // `scan_started` arrives at the very end. Show the running state
    // optimistically, before awaiting, or the UI would look frozen for the
    // whole scan.
    _isScanning = true;
    _scanProcessed = 0;
    _scanImported = 0;
    _scanFailedPath = null;
    _armScanWatchdog();
    notifyListeners();

    try {
      await _repository.rescan().drain<void>();
    } on MediaBackendException catch (error) {
      _logger.warning('Rescan failed: ${error.message}');
      if (error.kind == MediaErrorKind.offline) {
        _onStreamFailure?.call(error);
      }
    } finally {
      _isScanning = false;
      _scanWatchdog?.cancel();
      notifyListeners();
      await _search();
    }
  }

  Future<void> _load() async {
    _state = const MediaViewState.loading();
    notifyListeners();
    await _search();
  }

  Future<void> _search() async {
    final hadResults = _results.isNotEmpty;
    if (!hadResults) {
      _state = const MediaViewState.loading();
      notifyListeners();
    }

    try {
      await _repository.ensureLibraryLoaded();
      final serverResults = await _repository.search(_query);
      _results = _mergedWithPathMatches(serverResults);
      _state = _results.isEmpty
          ? MediaViewState.empty(
              _query.isEmpty
                  ? AppTextKey.mediaLibraryEmpty
                  : AppTextKey.mediaSearchNoResults,
            )
          : const MediaViewState.ready();
    } on MediaBackendException catch (error) {
      _logger.warning('Library search failed: ${error.message}');
      if (error.kind == MediaErrorKind.offline) {
        _state = const MediaViewState.offline();
        _onStreamFailure?.call(error);
      } else {
        _state = MediaViewState.error(AppTextKey.mediaBackendErrorDescription);
      }
    }

    notifyListeners();
  }

  /// `SearchMedia` only matches title/artist (`database.rs` `search_media`),
  /// never the file path, so a filename search would otherwise come back
  /// empty. This adds a local path filter over the cached library.
  List<MediaLibraryTrack> _mergedWithPathMatches(
    List<MediaLibraryTrack> serverResults,
  ) {
    if (_query.isEmpty) {
      return serverResults;
    }

    final seenIds = serverResults.map((track) => track.id).toSet();
    final lowerQuery = _query.toLowerCase();
    final pathMatches = _repository.cachedLibrary.where(
      (track) =>
          !seenIds.contains(track.id) &&
          track.path.toLowerCase().contains(lowerQuery),
    );

    return [...serverResults, ...pathMatches];
  }

  void _onLibraryEvent(LibraryScanEvent event) {
    switch (event.kind) {
      case LibraryScanEventKind.scanStarted:
        _isScanning = true;
        _scanProcessed = 0;
        _scanImported = 0;
        _scanFailedPath = null;
        _armScanWatchdog();
        notifyListeners();
      case LibraryScanEventKind.progress:
        _scanProcessed = event.processed;
        _scanImported = event.imported;
        _armScanWatchdog();
        notifyListeners();
      case LibraryScanEventKind.error:
        _scanFailedPath = event.path;
        _armScanWatchdog();
        notifyListeners();
      case LibraryScanEventKind.scanCompleted:
        _isScanning = false;
        _scanWatchdog?.cancel();
        notifyListeners();
        unawaited(_search());
      case LibraryScanEventKind.unknown:
        _logger.info('Ignoring unknown library event: ${event.message}');
    }
  }

  /// Guards against a lagged broadcast receiver silently dropping a
  /// `scan_completed` event (`main.rs` filters those with `event.ok()`),
  /// which would otherwise leave [isScanning] stuck forever.
  void _armScanWatchdog() {
    _scanWatchdog?.cancel();
    _scanWatchdog = Timer(_scanWatchdogDuration, () {
      _logger.warning('Scan watchdog fired - clearing a stuck scan flag');
      _isScanning = false;
      notifyListeners();
    });
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    _logger.warning('Library event stream failed', error, stackTrace);
    _onStreamFailure?.call(error);
  }
}
