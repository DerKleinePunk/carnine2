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
/// playlist's entries, creation, renaming, deleting, and adding or removing
/// entries.
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

  MediaPlaylist? _renameTarget;
  bool _isRenaming = false;
  AppTextKey? _renameErrorKey;

  /// A failed delete or entry removal. Shown briefly on the detail page.
  AppTextKey? _actionErrorKey;
  Timer? _actionErrorTimer;
  static const _actionErrorDuration = Duration(seconds: 4);
  final Set<int> _pendingRemoveEntryIds = {};

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

  /// The playlist the rename page is for, `null` while none is being renamed.
  MediaPlaylist? get renameTarget => _renameTarget;
  bool get isRenaming => _isRenaming;
  AppTextKey? get renameErrorKey => _renameErrorKey;
  AppTextKey? get actionErrorKey => _actionErrorKey;
  Set<int> get pendingRemoveEntryIds => _pendingRemoveEntryIds;
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

  void dismissActionError() {
    if (_actionErrorKey == null) {
      return;
    }
    _actionErrorTimer?.cancel();
    _actionErrorKey = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _actionErrorTimer?.cancel();
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
        if (_addPlaylist(
          MediaPlaylist(
            id: event.playlistId,
            name: event.playlistName,
            entries: const [],
          ),
        )) {
          notifyListeners();
        }
      case LibraryScanEventKind.playlistEntryAdded:
        // `ListPlaylists` never carries entries, so only the open detail
        // view (if it's the affected playlist) has anything to refresh.
        if (_openPlaylist?.id == event.playlistId) {
          unawaited(openPlaylistById(event.playlistId));
        }
      case LibraryScanEventKind.playlistRenamed:
        if (_applyRename(event.playlistId, event.playlistName)) {
          notifyListeners();
        }
      case LibraryScanEventKind.playlistDeleted:
        if (_forgetPlaylist(event.playlistId)) {
          notifyListeners();
        }
      case LibraryScanEventKind.playlistEntryRemoved:
        // Refreshed in place: `openPlaylistById` would blank the detail
        // page, and with it send the user back to the overview.
        if (_openPlaylist?.id == event.playlistId) {
          unawaited(_refreshOpenPlaylist(event.playlistId));
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

  /// Inserts [playlist] at its correctly sorted position instead of
  /// appending - `listPlaylists` orders `ORDER BY name COLLATE NOCASE, id`
  /// (`database.rs`), so a plain append would put a newly created playlist
  /// in the wrong spot (and easily scrolled out of view) until the next
  /// full reload.
  ///
  /// Both the create reply and the `playlistCreated` event land here, in
  /// either order, so a playlist already in the list is left alone (#46).
  /// Returns whether the list changed; it is then no longer empty either.
  bool _addPlaylist(MediaPlaylist playlist) {
    if (_playlists.any((existing) => existing.id == playlist.id)) {
      return false;
    }
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
    _listState = const MediaViewState.ready();
    return true;
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
    _clearOpenPlaylist();
    notifyListeners();
  }

  void _clearOpenPlaylist() {
    _openPlaylist = null;
    _openPlaylistCoverArt = null;
    _detailState = const MediaViewState.idle();
    _addedMediaIds.clear();
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
      _addPlaylist(playlist);
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

  /// Opens the rename page for [playlist].
  void startRenaming(MediaPlaylist playlist) {
    _renameTarget = playlist;
    _renameErrorKey = null;
    notifyListeners();
  }

  void cancelRename() {
    if (_renameTarget == null) {
      return;
    }
    _renameTarget = null;
    _renameErrorKey = null;
    notifyListeners();
  }

  /// Renames [renameTarget]. Returns whether the rename page can close - on
  /// success, or when the name did not change; on failure the reason is in
  /// [renameErrorKey].
  Future<bool> renamePlaylist(String name) async {
    final target = _renameTarget;
    if (target == null) {
      return false;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _renameErrorKey = AppTextKey.mediaPlaylistNameRequired;
      notifyListeners();
      return false;
    }
    if (trimmed == target.name) {
      cancelRename();
      return true;
    }

    _isRenaming = true;
    _renameErrorKey = null;
    notifyListeners();

    try {
      final renamed = await _repository.renamePlaylist(
        playlistId: target.id,
        name: trimmed,
      );
      _applyRename(renamed.id, renamed.name);
      _renameTarget = null;
      return true;
    } on MediaBackendException catch (error) {
      _logger.warning(
        'RenamePlaylist(${target.id}, "$trimmed") failed: ${error.message}',
      );
      _renameErrorKey = switch (error.kind) {
        MediaErrorKind.alreadyExists => AppTextKey.mediaPlaylistExistsError,
        MediaErrorKind.invalidInput => AppTextKey.mediaPlaylistNameRequired,
        MediaErrorKind.offline => AppTextKey.mediaOfflineDescription,
        _ => AppTextKey.mediaBackendErrorDescription,
      };
      if (error.kind == MediaErrorKind.offline) {
        _onStreamFailure?.call(error);
      }
      return false;
    } finally {
      _isRenaming = false;
      notifyListeners();
    }
  }

  /// Deletes [playlistId] with its entries. Returns whether it is gone - an
  /// unknown id counts, somebody else was faster.
  Future<bool> deletePlaylist(int playlistId) async {
    try {
      await _repository.deletePlaylist(playlistId);
    } on MediaBackendException catch (error) {
      _logger.warning('DeletePlaylist($playlistId) failed: ${error.message}');
      if (error.kind != MediaErrorKind.notFound) {
        _failAction(error);
        notifyListeners();
        return false;
      }
    }
    if (_forgetPlaylist(playlistId)) {
      notifyListeners();
    }
    return true;
  }

  /// Takes [entry] out of the open playlist. The backend answers with the
  /// playlist as it is now, so the page shows that rather than guessing.
  Future<void> removeEntry(MediaPlaylistEntry entry) async {
    if (!_pendingRemoveEntryIds.add(entry.id)) {
      return;
    }
    notifyListeners();

    try {
      final playlist = await _repository.removePlaylistEntry(entry.id);
      if (_openPlaylist?.id == playlist.id) {
        await _showOpenPlaylist(playlist);
      }
    } on MediaBackendException catch (error) {
      _logger.warning(
        'RemovePlaylistEntry(${entry.id}) failed: ${error.message}',
      );
      if (error.kind == MediaErrorKind.notFound) {
        // Already gone elsewhere - show how the playlist is now.
        unawaited(_refreshOpenPlaylist(entry.playlistId));
      } else {
        _failAction(error);
      }
    } finally {
      _pendingRemoveEntryIds.remove(entry.id);
      notifyListeners();
    }
  }

  void _failAction(MediaBackendException error) {
    if (error.kind == MediaErrorKind.offline) {
      _onStreamFailure?.call(error);
      return;
    }
    _actionErrorKey = AppTextKey.mediaCommandFailed;
    _actionErrorTimer?.cancel();
    _actionErrorTimer = Timer(_actionErrorDuration, dismissActionError);
  }

  /// Gives [playlistId] its new [name] in the overview (at its sorted place)
  /// and on the open detail page. The rename reply and the `playlistRenamed`
  /// event both land here, so a name that is already applied changes nothing.
  /// Returns whether anything changed.
  bool _applyRename(int playlistId, String name) {
    var changed = false;
    final open = _openPlaylist;
    if (open != null && open.id == playlistId && open.name != name) {
      _openPlaylist = MediaPlaylist(
        id: open.id,
        name: name,
        entries: open.entries,
        hasCoverArt: open.hasCoverArt,
      );
      changed = true;
    }
    final index = _playlists.indexWhere(
      (playlist) => playlist.id == playlistId,
    );
    if (index >= 0 && _playlists[index].name != name) {
      _playlists = [..._playlists]..removeAt(index);
      _addPlaylist(
        MediaPlaylist(id: playlistId, name: name, entries: const []),
      );
      changed = true;
    }
    return changed;
  }

  /// Drops everything that pointed at [playlistId]: the overview row, the
  /// open detail page, a pending rename or add-entries view. Returns whether
  /// anything changed.
  bool _forgetPlaylist(int playlistId) {
    var changed = false;
    if (_playlists.any((playlist) => playlist.id == playlistId)) {
      _playlists = _playlists
          .where((playlist) => playlist.id != playlistId)
          .toList();
      if (_playlists.isEmpty) {
        _listState = const MediaViewState.empty(AppTextKey.mediaPlaylistsEmpty);
      }
      changed = true;
    }
    if (_openPlaylist?.id == playlistId) {
      _clearOpenPlaylist();
      changed = true;
    }
    if (_renameTarget?.id == playlistId) {
      _renameTarget = null;
      changed = true;
    }
    if (_pendingAddEntriesTarget?.id == playlistId) {
      _pendingAddEntriesTarget = null;
      changed = true;
    }
    return changed;
  }

  /// Reloads the open playlist without going through the loading state.
  Future<void> _refreshOpenPlaylist(int playlistId) async {
    try {
      final playlist = await _repository.getPlaylist(playlistId);
      if (_openPlaylist?.id == playlistId) {
        await _showOpenPlaylist(playlist);
      }
    } on MediaBackendException catch (error) {
      _logger.warning('GetPlaylist($playlistId) failed: ${error.message}');
      if (error.kind == MediaErrorKind.offline) {
        _onStreamFailure?.call(error);
      }
    }
  }

  /// Shows [playlist] as the open one. Its cover comes after the entries,
  /// and only if the playlist still has one - removing the entry the cover
  /// was borrowed from changes or drops it.
  Future<void> _showOpenPlaylist(MediaPlaylist playlist) async {
    _openPlaylist = playlist;
    _detailState = playlist.entries.isEmpty
        ? const MediaViewState.empty(AppTextKey.mediaPlaylistDetailEmpty)
        : const MediaViewState.ready();
    _seedAddedMediaIds(playlist);
    if (!playlist.hasCoverArt) {
      _openPlaylistCoverArt = null;
    }
    notifyListeners();
    if (playlist.hasCoverArt) {
      final art = await _repository.getPlaylistCoverArt(playlist.id);
      if (_openPlaylist?.id == playlist.id) {
        _openPlaylistCoverArt = art;
        notifyListeners();
      }
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
