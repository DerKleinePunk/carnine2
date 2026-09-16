import 'dart:async';

import 'package:carnine_frontend/features/media/domain/media_backend_exception.dart';
import 'package:carnine_frontend/features/media/domain/media_repository.dart';
import 'package:carnine_frontend/features/media/domain/models/library_scan_event.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/presentation/models/media_view_state.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Presentation controller for playlists: the overview list, one open
/// playlist's entries, creation and adding entries.
///
/// `MediaService.ListPlaylists` never returns entries - only `GetPlaylist`
/// does - so the overview must never show a track count, and opening a
/// playlist always issues a fresh `GetPlaylist` call.
///
/// Subscribes to `StreamLibraryEvents` for as long as the media section is
/// visible (mirroring `LibraryController`), so a playlist created or a track
/// added from another session/device shows up without a restart.
class PlaylistController extends ChangeNotifier {
  PlaylistController({
    required this._repository,
    this._onStreamFailure,
    Logger? logger,
  }) : _logger = logger ?? Logger('PlaylistController');

  final MediaRepository _repository;
  final void Function(Object error)? _onStreamFailure;
  final Logger _logger;

  StreamSubscription<LibraryScanEvent>? _libraryEvents;

  MediaViewState _listState = const MediaViewState.loading();
  List<MediaPlaylist> _playlists = const [];

  MediaPlaylist? _openPlaylist;
  MediaViewState _detailState = const MediaViewState.idle();
  Uint8List? _openPlaylistCoverArt;

  bool _isCreating = false;
  AppTextKey? _createErrorKey;

  final Set<int> _pendingAddMediaIds = {};
  final Set<int> _addedMediaIds = {};
  AppTextKey? _addEntryHintKey;
  Timer? _addEntryHintTimer;
  static const _addEntryHintDuration = Duration(seconds: 3);

  /// Set right after [createPlaylist] succeeds, so the "create" sub-page can
  /// hand off straight to adding tracks - "Playlist anlegen + befüllen" as
  /// one uninterrupted flow. The consumer clears it via
  /// [consumePendingAddEntriesTarget] once it has switched to that view.
  MediaPlaylist? _pendingAddEntriesTarget;

  MediaViewState get listState => _listState;
  List<MediaPlaylist> get playlists => _playlists;
  MediaPlaylist? get openPlaylist => _openPlaylist;
  MediaViewState get detailState => _detailState;
  Uint8List? get openPlaylistCoverArt => _openPlaylistCoverArt;
  bool get isCreating => _isCreating;
  AppTextKey? get createErrorKey => _createErrorKey;
  Set<int> get pendingAddMediaIds => _pendingAddMediaIds;
  Set<int> get addedMediaIds => _addedMediaIds;
  MediaPlaylist? get pendingAddEntriesTarget => _pendingAddEntriesTarget;
  AppTextKey? get addEntryHintKey => _addEntryHintKey;

  /// Clears [pendingAddEntriesTarget] once the caller has switched to the
  /// add-entries view for it.
  void consumePendingAddEntriesTarget() {
    _pendingAddEntriesTarget = null;
    notifyListeners();
  }

  void dismissAddEntryHint() {
    if (_addEntryHintKey == null) {
      return;
    }
    _addEntryHintTimer?.cancel();
    _addEntryHintKey = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _addEntryHintTimer?.cancel();
    _libraryEvents?.cancel();
    super.dispose();
  }

  /// Subscribes to the library event stream and loads the playlists. Safe to
  /// call again after [reconnect] tore the previous subscription down.
  Future<void> start() async {
    await _libraryEvents?.cancel();
    _libraryEvents = _repository.libraryEvents().listen(
      _onLibraryEvent,
      onError: _onStreamError,
    );
    await loadPlaylists();
  }

  /// Re-subscribes to the library event stream and reloads the playlists
  /// after the underlying transport was rebuilt.
  Future<void> reconnect() => start();

  void _onStreamError(Object error) {
    _logger.warning('Playlist event stream failed: $error');
    _onStreamFailure?.call(error);
  }

  void _onLibraryEvent(LibraryScanEvent event) {
    switch (event.kind) {
      case LibraryScanEventKind.playlistCreated:
        if (_playlists.any((playlist) => playlist.id == event.playlistId)) {
          return;
        }
        _playlists = [
          ..._playlists,
          MediaPlaylist(
            id: event.playlistId,
            name: event.playlistName,
            entries: const [],
          ),
        ];
        _listState = const MediaViewState.ready();
        notifyListeners();
      case LibraryScanEventKind.playlistEntryAdded:
        // `ListPlaylists` never carries entries, so only the open detail
        // view (if it's the affected playlist) has anything to refresh.
        if (_openPlaylist?.id == event.playlistId) {
          unawaited(openPlaylistById(event.playlistId));
        }
      default:
        break;
    }
  }

  Future<void> loadPlaylists() async {
    _listState = const MediaViewState.loading();
    notifyListeners();

    try {
      _playlists = await _repository.listPlaylists();
      _listState = _playlists.isEmpty
          ? const MediaViewState.empty(AppTextKey.mediaPlaylistsEmpty)
          : const MediaViewState.ready();
    } on MediaBackendException catch (error) {
      _logger.warning('ListPlaylists failed: ${error.message}');
      if (error.kind == MediaErrorKind.offline) {
        _listState = const MediaViewState.offline();
        _onStreamFailure?.call(error);
      } else {
        _listState = const MediaViewState.error(
          AppTextKey.mediaBackendErrorDescription,
        );
      }
    }

    notifyListeners();
  }

  Future<void> openPlaylistById(int playlistId) async {
    _detailState = const MediaViewState.loading();
    _openPlaylist = null;
    _openPlaylistCoverArt = null;
    notifyListeners();

    try {
      // Entries are resolved against the library cache in the repository,
      // so the cache must exist first.
      await _repository.ensureLibraryLoaded();
      final playlist = await _repository.getPlaylist(playlistId);
      _openPlaylist = playlist;
      _detailState = playlist.entries.isEmpty
          ? const MediaViewState.empty(AppTextKey.mediaPlaylistDetailEmpty)
          : const MediaViewState.ready();
      // `getPlaylist` is the one call that reports `hasCoverArt` accurately
      // (`listPlaylists` always says `false`), so this is the only place a
      // cover fetch is worth attempting.
      if (playlist.hasCoverArt) {
        _openPlaylistCoverArt = await _repository.getPlaylistCoverArt(
          playlistId,
        );
      }
    } on MediaBackendException catch (error) {
      _logger.warning('GetPlaylist($playlistId) failed: ${error.message}');
      if (error.kind == MediaErrorKind.offline) {
        _detailState = const MediaViewState.offline();
        _onStreamFailure?.call(error);
      } else {
        _detailState = const MediaViewState.error(
          AppTextKey.mediaBackendErrorDescription,
        );
      }
    }

    notifyListeners();
  }

  /// Fetches [playlistId] with its entries resolved, without touching
  /// [openPlaylist]/[detailState] - for a caller (the Collections overview's
  /// inline Play button) that needs the track list to start playback but
  /// must not navigate to the detail page as a side effect. `listPlaylists`
  /// (which backs the overview) never returns entries, so this is the only
  /// way that button can ever get playable tracks.
  Future<MediaPlaylist?> fetchPlaylistForPlayback(int playlistId) async {
    try {
      await _repository.ensureLibraryLoaded();
      return await _repository.getPlaylist(playlistId);
    } on MediaBackendException catch (error) {
      _logger.warning(
        'GetPlaylist($playlistId) for inline playback failed: '
        '${error.message}',
      );
      if (error.kind == MediaErrorKind.offline) {
        _onStreamFailure?.call(error);
      }
      return null;
    }
  }

  /// Switches to the add-entries view for [playlist], from either the
  /// detail page or right after creation.
  void startAddingEntries(MediaPlaylist playlist) {
    _seedAddedMediaIds(playlist);
    _pendingAddEntriesTarget = playlist;
    notifyListeners();
  }

  /// Seeds [_addedMediaIds] with [playlist]'s current entries, so a track
  /// already in the playlist (from a previous session, not just ones added
  /// just now) reads as already-added rather than being offered again.
  void _seedAddedMediaIds(MediaPlaylist playlist) {
    _addedMediaIds
      ..clear()
      ..addAll(playlist.entries.map((entry) => entry.mediaId));
  }

  void closePlaylist() {
    _openPlaylist = null;
    _openPlaylistCoverArt = null;
    _detailState = const MediaViewState.idle();
    _addedMediaIds.clear();
    notifyListeners();
  }

  /// Returns the created playlist's id on success, `null` on failure (the
  /// caller advances to the add-entries step only on success).
  Future<int?> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _createErrorKey = AppTextKey.mediaPlaylistNameRequired;
      notifyListeners();
      return null;
    }

    _isCreating = true;
    _createErrorKey = null;
    notifyListeners();

    try {
      final playlist = await _repository.createPlaylist(trimmed);
      _playlists = [..._playlists, playlist];
      _seedAddedMediaIds(playlist);
      _pendingAddEntriesTarget = playlist;
      return playlist.id;
    } on MediaBackendException catch (error) {
      _logger.warning('CreatePlaylist("$trimmed") failed: ${error.message}');
      _createErrorKey = switch (error.kind) {
        MediaErrorKind.alreadyExists => AppTextKey.mediaPlaylistExistsError,
        MediaErrorKind.invalidInput => AppTextKey.mediaPlaylistNameRequired,
        MediaErrorKind.offline => AppTextKey.mediaOfflineDescription,
        _ => AppTextKey.mediaBackendErrorDescription,
      };
      if (error.kind == MediaErrorKind.offline) {
        _onStreamFailure?.call(error);
      }
      return null;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<void> addEntry({required int playlistId, required int mediaId}) async {
    if (_pendingAddMediaIds.contains(mediaId)) {
      return;
    }
    if (_addedMediaIds.contains(mediaId)) {
      _addEntryHintKey = AppTextKey.mediaPlaylistTrackAlreadyAdded;
      notifyListeners();
      _addEntryHintTimer?.cancel();
      _addEntryHintTimer = Timer(_addEntryHintDuration, dismissAddEntryHint);
      return;
    }

    _pendingAddMediaIds.add(mediaId);
    notifyListeners();

    try {
      await _repository.addPlaylistEntry(
        playlistId: playlistId,
        mediaId: mediaId,
      );
      _addedMediaIds.add(mediaId);
    } on MediaBackendException catch (error) {
      _logger.warning(
        'AddPlaylistEntry(playlist: $playlistId, media: $mediaId) failed: '
        '${error.message}',
      );
      if (error.kind == MediaErrorKind.offline) {
        _onStreamFailure?.call(error);
      }
    } finally {
      _pendingAddMediaIds.remove(mediaId);
      notifyListeners();
    }
  }
}
