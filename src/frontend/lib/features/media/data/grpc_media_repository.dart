import 'dart:typed_data';

import 'package:carnine_frontend/features/media/data/media_channel.dart';
import 'package:carnine_frontend/features/media/data/media_error_mapper.dart';
import 'package:carnine_frontend/features/media/data/proto_mappers.dart';
import 'package:carnine_frontend/features/media/domain/media_backend_exception.dart';
import 'package:carnine_frontend/features/media/domain/media_repository.dart';
import 'package:carnine_frontend/features/media/domain/models/library_scan_event.dart';
import 'package:carnine_frontend/features/media/domain/models/audio_event.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/domain/models/player_event_update.dart';
import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart' hide AudioEvent;
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';

/// gRPC-backed [MediaRepository]; the only place `MediaServiceClient` is
/// used directly.
class GrpcMediaRepository implements MediaRepository {
  GrpcMediaRepository({MediaChannel? channel, Logger? logger})
    : _channel = channel ?? MediaChannel(),
      _logger = logger ?? Logger('GrpcMediaRepository');

  // Play/Pause/Stop/Next/Previous can wait for external audio processes
  // (ffmpeg, paplay/aplay) to actually exit before returning - occasionally
  // slower than a plain state mutation, especially under WSL's PulseAudio
  // bridge. 2s was too tight and made track switches spuriously look like a
  // dropped connection.
  static const _commandTimeout = Duration(seconds: 6);
  static const _searchTimeout = Duration(seconds: 5);

  final MediaChannel _channel;
  final Logger _logger;

  final List<MediaLibraryTrack> _all = <MediaLibraryTrack>[];
  final Map<String, MediaLibraryTrack> _byPath = <String, MediaLibraryTrack>{};
  final Map<int, MediaLibraryTrack> _byId = <int, MediaLibraryTrack>{};
  bool _libraryLoadedOnce = false;

  @override
  List<MediaLibraryTrack> get cachedLibrary => List.unmodifiable(_all);

  @override
  MediaLibraryTrack? trackForPath(String path) => _byPath[path];

  @override
  MediaLibraryTrack? trackForId(int mediaId) => _byId[mediaId];

  @override
  Future<List<MediaLibraryTrack>> loadLibrary() async {
    final tracks = await _search('');
    _all
      ..clear()
      ..addAll(tracks);
    _reindex(tracks);
    _libraryLoadedOnce = true;
    return cachedLibrary;
  }

  @override
  Future<List<MediaLibraryTrack>> search(String query) async {
    final tracks = await _search(query);
    _reindex(tracks);
    return List.unmodifiable(tracks);
  }

  @override
  Future<void> ensureLibraryLoaded() async {
    if (!_libraryLoadedOnce) {
      await loadLibrary();
    }
  }

  Future<List<MediaLibraryTrack>> _search(String query) async {
    try {
      final response = await _channel.stub.searchMedia(
        SearchMediaRequest(query: query),
        options: CallOptions(timeout: _searchTimeout),
      );
      final tracks = response.items.map(trackFromProto).toList();
      _logger.info('Search "$query" returned ${tracks.length} tracks');
      return tracks;
    } catch (error, stackTrace) {
      _logger.severe(
        'SearchMedia failed for query "$query"',
        error,
        stackTrace,
      );
      throw mediaExceptionFrom(error);
    }
  }

  void _reindex(List<MediaLibraryTrack> tracks) {
    for (final track in tracks) {
      _byPath[track.path] = track;
      _byId[track.id] = track;
    }
  }

  @override
  Future<PlayerSnapshot> playerState() async {
    try {
      final state = await _channel.stub.getPlayerState(
        Empty(),
        options: CallOptions(timeout: _commandTimeout),
      );
      return snapshotFromProto(state);
    } catch (error, stackTrace) {
      _logger.severe('GetPlayerState failed', error, stackTrace);
      throw mediaExceptionFrom(error);
    }
  }

  @override
  Future<void> startTrack(String mediaPath) async {
    await _command(
      'Stop',
      () => _channel.stub.stop(
        Empty(),
        options: CallOptions(timeout: _commandTimeout),
      ),
    );
    await _command(
      'Play',
      () => _channel.stub.play(
        PlayRequest(mediaPath: mediaPath),
        options: CallOptions(timeout: _commandTimeout),
      ),
    );
  }

  @override
  Future<void> resume() {
    return _command(
      'Play',
      () => _channel.stub.play(
        PlayRequest(mediaPath: ''),
        options: CallOptions(timeout: _commandTimeout),
      ),
    );
  }

  @override
  Future<void> pause() {
    return _command(
      'Pause',
      () => _channel.stub.pause(
        Empty(),
        options: CallOptions(timeout: _commandTimeout),
      ),
    );
  }

  @override
  Future<void> stop() {
    return _command(
      'Stop',
      () => _channel.stub.stop(
        Empty(),
        options: CallOptions(timeout: _commandTimeout),
      ),
    );
  }

  @override
  Future<void> next() {
    return _command(
      'Next',
      () => _channel.stub.next(
        Empty(),
        options: CallOptions(timeout: _commandTimeout),
      ),
    );
  }

  @override
  Future<void> previous() {
    return _command(
      'Previous',
      () => _channel.stub.previous(
        Empty(),
        options: CallOptions(timeout: _commandTimeout),
      ),
    );
  }

  @override
  Future<void> restartCurrentTrack() {
    return _command(
      'RestartCurrentTrack',
      () => _channel.stub.restartCurrentTrack(
        Empty(),
        options: CallOptions(timeout: _commandTimeout),
      ),
    );
  }

  @override
  Future<void> playQueueEntry(int index) {
    return _command(
      'PlayQueueEntry',
      () => _channel.stub.playQueueEntry(
        PlayQueueEntryRequest(index: index),
        options: CallOptions(timeout: _commandTimeout),
      ),
    );
  }

  @override
  Future<void> setRepeatMode(MediaRepeatMode mode) {
    return _command(
      'SetRepeatMode',
      () => _channel.stub.setRepeatMode(
        SetRepeatModeRequest(mode: repeatModeToProto(mode)),
        options: CallOptions(timeout: _commandTimeout),
      ),
    );
  }

  @override
  Future<void> setShuffleMode(bool enabled) {
    return _command(
      'SetShuffleMode',
      () => _channel.stub.setShuffleMode(
        SetShuffleModeRequest(enabled: enabled),
        options: CallOptions(timeout: _commandTimeout),
      ),
    );
  }

  @override
  Future<void> startPlaylist(int playlistId) async {
    await _command(
      'PlayPlaylist',
      () => _channel.stub.playPlaylist(
        PlayPlaylistRequest(playlistId: Int64(playlistId)),
        options: CallOptions(timeout: _commandTimeout),
      ),
    );
    await _command(
      'Play',
      () => _channel.stub.play(
        PlayRequest(mediaPath: ''),
        options: CallOptions(timeout: _commandTimeout),
      ),
    );
  }

  Future<void> _command(
    String name,
    Future<CommandResponse> Function() call,
  ) async {
    try {
      await call();
      _logger.info('$name succeeded');
    } catch (error, stackTrace) {
      _logger.severe('$name failed', error, stackTrace);
      throw mediaExceptionFrom(error);
    }
  }

  @override
  Stream<PlayerEventUpdate> playerEvents() {
    return _channel.stub.streamPlayerEvents(Empty()).map(playerEventFromProto);
  }

  @override
  Stream<LibraryScanEvent> libraryEvents() {
    return _channel.stub.streamLibraryEvents(Empty()).map(scanEventFromProto);
  }

  @override
  Stream<AudioEvent> audioEvents() {
    return _channel.audioStub
        .streamAudioEvents(Empty())
        .map(audioEventFromProto);
  }

  @override
  Future<int> getVolume() async {
    try {
      final response = await _channel.audioStub.getVolume(
        Empty(),
        options: CallOptions(timeout: _commandTimeout),
      );
      return response.percent;
    } catch (error, stackTrace) {
      _logger.severe('GetVolume failed', error, stackTrace);
      throw mediaExceptionFrom(error);
    }
  }

  @override
  Future<int> setVolume(int percent) async {
    try {
      final response = await _channel.audioStub.setVolume(
        SetVolumeRequest(percent: percent),
        options: CallOptions(timeout: _commandTimeout),
      );
      return response.percent;
    } catch (error, stackTrace) {
      _logger.severe('SetVolume($percent) failed', error, stackTrace);
      throw mediaExceptionFrom(error);
    }
  }

  @override
  Stream<LibraryScanEvent> rescan() {
    return _channel.stub
        .rescanMedia(RescanMediaRequest())
        .map(scanEventFromProto);
  }

  @override
  Stream<LibraryScanEvent> importMusicVolume(String sourcePath) {
    return _channel.stub
        .importMusicVolume(ImportMusicVolumeRequest(sourcePath: sourcePath))
        .map(scanEventFromProto);
  }

  @override
  Future<List<MediaPlaylist>> listPlaylists() async {
    try {
      final response = await _channel.stub.listPlaylists(
        Empty(),
        options: CallOptions(timeout: _commandTimeout),
      );
      return response.playlists
          .map(
            (playlist) => MediaPlaylist(
              id: idFrom(playlist.id),
              name: playlist.name,
              entries: const [],
            ),
          )
          .toList();
    } catch (error, stackTrace) {
      _logger.severe('ListPlaylists failed', error, stackTrace);
      throw mediaExceptionFrom(error);
    }
  }

  @override
  Future<MediaPlaylist> getPlaylist(int playlistId) async {
    try {
      final playlist = await _channel.stub.getPlaylist(
        GetPlaylistRequest(playlistId: Int64(playlistId)),
        options: CallOptions(timeout: _commandTimeout),
      );
      final entries = playlist.entries
          .map(
            (entry) => MediaPlaylistEntry(
              id: idFrom(entry.id),
              playlistId: idFrom(entry.playlistId),
              mediaId: idFrom(entry.mediaId),
              position: idFrom(entry.position),
              track: trackForId(idFrom(entry.mediaId)),
            ),
          )
          .toList();
      return MediaPlaylist(
        id: idFrom(playlist.id),
        name: playlist.name,
        entries: entries,
        hasCoverArt: playlist.hasCoverArt,
      );
    } catch (error, stackTrace) {
      _logger.severe('GetPlaylist($playlistId) failed', error, stackTrace);
      throw mediaExceptionFrom(error);
    }
  }

  @override
  Future<MediaPlaylist> createPlaylist(String name) async {
    try {
      final playlist = await _channel.stub.createPlaylist(
        CreatePlaylistRequest(name: name),
        options: CallOptions(timeout: _commandTimeout),
      );
      return MediaPlaylist(
        id: idFrom(playlist.id),
        name: playlist.name,
        entries: const [],
      );
    } catch (error, stackTrace) {
      _logger.severe('CreatePlaylist("$name") failed', error, stackTrace);
      throw mediaExceptionFrom(error);
    }
  }

  @override
  Future<MediaPlaylistEntry> addPlaylistEntry({
    required int playlistId,
    required int mediaId,
  }) async {
    try {
      final entry = await _channel.stub.addPlaylistEntry(
        AddPlaylistEntryRequest(
          playlistId: Int64(playlistId),
          mediaId: Int64(mediaId),
        ),
        options: CallOptions(timeout: _commandTimeout),
      );
      return MediaPlaylistEntry(
        id: idFrom(entry.id),
        playlistId: idFrom(entry.playlistId),
        mediaId: idFrom(entry.mediaId),
        position: idFrom(entry.position),
        track: trackForId(mediaId),
      );
    } catch (error, stackTrace) {
      _logger.severe(
        'AddPlaylistEntry(playlist: $playlistId, media: $mediaId) failed',
        error,
        stackTrace,
      );
      throw mediaExceptionFrom(error);
    }
  }

  @override
  Future<Uint8List?> getTrackCoverArt(int mediaId) {
    return _coverArt(
      'GetCoverArt(media: $mediaId)',
      () => _channel.stub.getCoverArt(
        GetCoverArtRequest(mediaId: Int64(mediaId)),
        options: CallOptions(timeout: _commandTimeout),
      ),
    );
  }

  @override
  Future<Uint8List?> getPlaylistCoverArt(int playlistId) {
    return _coverArt(
      'GetCoverArt(playlist: $playlistId)',
      () => _channel.stub.getCoverArt(
        GetCoverArtRequest(playlistId: Int64(playlistId)),
        options: CallOptions(timeout: _commandTimeout),
      ),
    );
  }

  /// Cover art is decorative, so a failure never surfaces as an exception -
  /// callers just keep their icon fallback. `notFound` (no cover stored) is
  /// expected and logged quietly; anything else is a real backend problem
  /// and logged as a warning.
  Future<Uint8List?> _coverArt(
    String name,
    Future<GetCoverArtResponse> Function() call,
  ) async {
    try {
      final response = await call();
      return Uint8List.fromList(response.data);
    } catch (error, stackTrace) {
      final mapped = mediaExceptionFrom(error);
      if (mapped.kind == MediaErrorKind.notFound) {
        _logger.info('$name: no cover art available');
      } else {
        _logger.warning('$name failed', error, stackTrace);
      }
      return null;
    }
  }

  @override
  Future<void> reconnect() => _channel.reconnect();

  @override
  Future<void> dispose() => _channel.shutdown();
}
