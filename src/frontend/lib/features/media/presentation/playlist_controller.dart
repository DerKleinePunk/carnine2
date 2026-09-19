import 'dart:async';

import 'package:carnine_frontend/features/media/domain/media_backend_exception.dart';
import 'package:carnine_frontend/features/media/domain/media_repository.dart';
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
class PlaylistController extends ChangeNotifier {
  PlaylistController({
    required this._repository,
    this._onStreamFailure,
    Logger? logger,
  }) : _logger = logger ?? Logger('PlaylistController');

  final MediaRepository _repository;
  final void Function(Object error)? _onStreamFailure;
  final Logger _logger;

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
    super.dispose();
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

  /// Inserts [playlist] at its correctly sorted position instead of
  /// appending - `listPlaylists` orders `ORDER BY name COLLATE NOCASE, id`
  /// (`database.rs`), so a plain append would put a newly created playlist
  /// in the wrong spot (and easily scrolled out of view) until the next
  /// full reload.
  void _insertPlaylistSorted(MediaPlaylist playlist) {
    final name = playlist.name.toLowerCase();
    var index = _playlists.length;
    for (var i = 0; i < _playlists.length; i++) {
      final existingName = _playlists[i].name.toLowerCase();
      if (existingName.compareTo(name) > 0 ||
          (existingName == name && _playlists[i].id > playlist.id)) {
        index = i;
        break;
      }
    }
    _playlists = [
      ..._playlists.sublist(0, index),
      playlist,
      ..._playlists.sublist(index),
    ];
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
      _insertPlaylistSorted(playlist);
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

  /// Reflects a just-added [entry] in [openPlaylist] immediately, if it's
  /// the playlist currently shown on the detail page - otherwise a track
  /// added from "Titel hinzufügen" only shows up there after fully leaving
  /// and re-opening the playlist, since [openPlaylistById] is the only
  /// other thing that ever populates `entries`.
  void _appendEntryIfPlaylistOpen(int playlistId, MediaPlaylistEntry entry) {
    final current = _openPlaylist;
    if (current == null || current.id != playlistId) {
      return;
    }
    _openPlaylist = MediaPlaylist(
      id: current.id,
      name: current.name,
      entries: [...current.entries, entry],
      hasCoverArt: current.hasCoverArt,
    );
    _detailState = const MediaViewState.ready();
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
      final entry = await _repository.addPlaylistEntry(
        playlistId: playlistId,
        mediaId: mediaId,
      );
      _addedMediaIds.add(mediaId);
      _appendEntryIfPlaylistOpen(playlistId, entry);
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
