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
    required MediaRepository repository,
    void Function(Object error)? onStreamFailure,
    Logger? logger,
  })  : _repository = repository,
        _onStreamFailure = onStreamFailure,
        _logger = logger ?? Logger('PlaylistController');

  final MediaRepository _repository;
  final void Function(Object error)? _onStreamFailure;
  final Logger _logger;

  MediaViewState _listState = const MediaViewState.loading();
  List<MediaPlaylist> _playlists = const [];

  MediaPlaylist? _openPlaylist;
  MediaViewState _detailState = const MediaViewState.idle();

  bool _isCreating = false;
  AppTextKey? _createErrorKey;

  final Set<int> _pendingAddMediaIds = {};
  final Set<int> _addedMediaIds = {};

  /// Set right after [createPlaylist] succeeds, so the "create" sub-page can
  /// hand off straight to adding tracks - "Playlist anlegen + befüllen" as
  /// one uninterrupted flow. The consumer clears it via
  /// [consumePendingAddEntriesTarget] once it has switched to that view.
  MediaPlaylist? _pendingAddEntriesTarget;

  MediaViewState get listState => _listState;
  List<MediaPlaylist> get playlists => _playlists;
  MediaPlaylist? get openPlaylist => _openPlaylist;
  MediaViewState get detailState => _detailState;
  bool get isCreating => _isCreating;
  AppTextKey? get createErrorKey => _createErrorKey;
  Set<int> get pendingAddMediaIds => _pendingAddMediaIds;
  Set<int> get addedMediaIds => _addedMediaIds;
  MediaPlaylist? get pendingAddEntriesTarget => _pendingAddEntriesTarget;

  /// Clears [pendingAddEntriesTarget] once the caller has switched to the
  /// add-entries view for it.
  void consumePendingAddEntriesTarget() {
    _pendingAddEntriesTarget = null;
    notifyListeners();
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

  /// Switches to the add-entries view for [playlist], from either the
  /// detail page or right after creation.
  void startAddingEntries(MediaPlaylist playlist) {
    _pendingAddEntriesTarget = playlist;
    notifyListeners();
  }

  void closePlaylist() {
    _openPlaylist = null;
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
    if (_pendingAddMediaIds.contains(mediaId) ||
        _addedMediaIds.contains(mediaId)) {
      return;
    }

    _pendingAddMediaIds.add(mediaId);
    notifyListeners();

    try {
      await _repository.addPlaylistEntry(
          playlistId: playlistId, mediaId: mediaId);
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
