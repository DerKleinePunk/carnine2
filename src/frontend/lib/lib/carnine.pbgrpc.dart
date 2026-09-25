// This is a generated file - do not edit.
//
// Generated from carnine.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'carnine.pb.dart' as $0;

export 'carnine.pb.dart';

@$pb.GrpcServiceName('carnine.CarnineService')
class CarnineServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  CarnineServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.CanDataResponse> getCanData(
    $0.CanDataRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getCanData, request, options: options);
  }

  // method descriptors

  static final _$getCanData =
      $grpc.ClientMethod<$0.CanDataRequest, $0.CanDataResponse>(
          '/carnine.CarnineService/GetCanData',
          ($0.CanDataRequest value) => value.writeToBuffer(),
          $0.CanDataResponse.fromBuffer);
}

@$pb.GrpcServiceName('carnine.CarnineService')
abstract class CarnineServiceBase extends $grpc.Service {
  $core.String get $name => 'carnine.CarnineService';

  CarnineServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CanDataRequest, $0.CanDataResponse>(
        'GetCanData',
        getCanData_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CanDataRequest.fromBuffer(value),
        ($0.CanDataResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.CanDataResponse> getCanData_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CanDataRequest> $request) async {
    return getCanData($call, await $request);
  }

  $async.Future<$0.CanDataResponse> getCanData(
      $grpc.ServiceCall call, $0.CanDataRequest request);
}

@$pb.GrpcServiceName('carnine.MediaService')
class MediaServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  MediaServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.ServiceVersion> getServiceVersion(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getServiceVersion, request, options: options);
  }

  $grpc.ResponseFuture<$0.CommandResponse> play(
    $0.PlayRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$play, request, options: options);
  }

  $grpc.ResponseFuture<$0.CommandResponse> pause(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$pause, request, options: options);
  }

  $grpc.ResponseFuture<$0.CommandResponse> stop(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$stop, request, options: options);
  }

  $grpc.ResponseFuture<$0.CommandResponse> next(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$next, request, options: options);
  }

  $grpc.ResponseFuture<$0.CommandResponse> previous(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$previous, request, options: options);
  }

  $grpc.ResponseFuture<$0.CommandResponse> restartCurrentTrack(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$restartCurrentTrack, request, options: options);
  }

  $grpc.ResponseFuture<$0.CommandResponse> playQueueEntry(
    $0.PlayQueueEntryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$playQueueEntry, request, options: options);
  }

  $grpc.ResponseFuture<$0.CommandResponse> playPlaylist(
    $0.PlayPlaylistRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$playPlaylist, request, options: options);
  }

  $grpc.ResponseFuture<$0.PlayerState> getPlayerState(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getPlayerState, request, options: options);
  }

  $grpc.ResponseFuture<$0.SearchMediaResponse> searchMedia(
    $0.SearchMediaRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$searchMedia, request, options: options);
  }

  $grpc.ResponseStream<$0.LibraryEvent> importMusicVolume(
    $0.ImportMusicVolumeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$importMusicVolume, $async.Stream.fromIterable([request]),
        options: options);
  }

  $grpc.ResponseStream<$0.LibraryEvent> rescanMedia(
    $0.RescanMediaRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$rescanMedia, $async.Stream.fromIterable([request]),
        options: options);
  }

  $grpc.ResponseStream<$0.LibraryEvent> streamLibraryEvents(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$streamLibraryEvents, $async.Stream.fromIterable([request]),
        options: options);
  }

  $grpc.ResponseFuture<$0.Playlist> createPlaylist(
    $0.CreatePlaylistRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createPlaylist, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListPlaylistsResponse> listPlaylists(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listPlaylists, request, options: options);
  }

  $grpc.ResponseFuture<$0.PlaylistEntry> addPlaylistEntry(
    $0.AddPlaylistEntryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$addPlaylistEntry, request, options: options);
  }

  $grpc.ResponseFuture<$0.Playlist> getPlaylist(
    $0.GetPlaylistRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getPlaylist, request, options: options);
  }

  $grpc.ResponseStream<$0.PlayerEvent> streamPlayerEvents(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$streamPlayerEvents, $async.Stream.fromIterable([request]),
        options: options);
  }

  $grpc.ResponseFuture<$0.GetCoverArtResponse> getCoverArt(
    $0.GetCoverArtRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getCoverArt, request, options: options);
  }

  $grpc.ResponseFuture<$0.CommandResponse> setRepeatMode(
    $0.SetRepeatModeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$setRepeatMode, request, options: options);
  }

  $grpc.ResponseFuture<$0.CommandResponse> setShuffleMode(
    $0.SetShuffleModeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$setShuffleMode, request, options: options);
  }

  // method descriptors

  static final _$getServiceVersion =
      $grpc.ClientMethod<$0.Empty, $0.ServiceVersion>(
          '/carnine.MediaService/GetServiceVersion',
          ($0.Empty value) => value.writeToBuffer(),
          $0.ServiceVersion.fromBuffer);
  static final _$play = $grpc.ClientMethod<$0.PlayRequest, $0.CommandResponse>(
      '/carnine.MediaService/Play',
      ($0.PlayRequest value) => value.writeToBuffer(),
      $0.CommandResponse.fromBuffer);
  static final _$pause = $grpc.ClientMethod<$0.Empty, $0.CommandResponse>(
      '/carnine.MediaService/Pause',
      ($0.Empty value) => value.writeToBuffer(),
      $0.CommandResponse.fromBuffer);
  static final _$stop = $grpc.ClientMethod<$0.Empty, $0.CommandResponse>(
      '/carnine.MediaService/Stop',
      ($0.Empty value) => value.writeToBuffer(),
      $0.CommandResponse.fromBuffer);
  static final _$next = $grpc.ClientMethod<$0.Empty, $0.CommandResponse>(
      '/carnine.MediaService/Next',
      ($0.Empty value) => value.writeToBuffer(),
      $0.CommandResponse.fromBuffer);
  static final _$previous = $grpc.ClientMethod<$0.Empty, $0.CommandResponse>(
      '/carnine.MediaService/Previous',
      ($0.Empty value) => value.writeToBuffer(),
      $0.CommandResponse.fromBuffer);
  static final _$restartCurrentTrack =
      $grpc.ClientMethod<$0.Empty, $0.CommandResponse>(
          '/carnine.MediaService/RestartCurrentTrack',
          ($0.Empty value) => value.writeToBuffer(),
          $0.CommandResponse.fromBuffer);
  static final _$playQueueEntry =
      $grpc.ClientMethod<$0.PlayQueueEntryRequest, $0.CommandResponse>(
          '/carnine.MediaService/PlayQueueEntry',
          ($0.PlayQueueEntryRequest value) => value.writeToBuffer(),
          $0.CommandResponse.fromBuffer);
  static final _$playPlaylist =
      $grpc.ClientMethod<$0.PlayPlaylistRequest, $0.CommandResponse>(
          '/carnine.MediaService/PlayPlaylist',
          ($0.PlayPlaylistRequest value) => value.writeToBuffer(),
          $0.CommandResponse.fromBuffer);
  static final _$getPlayerState = $grpc.ClientMethod<$0.Empty, $0.PlayerState>(
      '/carnine.MediaService/GetPlayerState',
      ($0.Empty value) => value.writeToBuffer(),
      $0.PlayerState.fromBuffer);
  static final _$searchMedia =
      $grpc.ClientMethod<$0.SearchMediaRequest, $0.SearchMediaResponse>(
          '/carnine.MediaService/SearchMedia',
          ($0.SearchMediaRequest value) => value.writeToBuffer(),
          $0.SearchMediaResponse.fromBuffer);
  static final _$importMusicVolume =
      $grpc.ClientMethod<$0.ImportMusicVolumeRequest, $0.LibraryEvent>(
          '/carnine.MediaService/ImportMusicVolume',
          ($0.ImportMusicVolumeRequest value) => value.writeToBuffer(),
          $0.LibraryEvent.fromBuffer);
  static final _$rescanMedia =
      $grpc.ClientMethod<$0.RescanMediaRequest, $0.LibraryEvent>(
          '/carnine.MediaService/RescanMedia',
          ($0.RescanMediaRequest value) => value.writeToBuffer(),
          $0.LibraryEvent.fromBuffer);
  static final _$streamLibraryEvents =
      $grpc.ClientMethod<$0.Empty, $0.LibraryEvent>(
          '/carnine.MediaService/StreamLibraryEvents',
          ($0.Empty value) => value.writeToBuffer(),
          $0.LibraryEvent.fromBuffer);
  static final _$createPlaylist =
      $grpc.ClientMethod<$0.CreatePlaylistRequest, $0.Playlist>(
          '/carnine.MediaService/CreatePlaylist',
          ($0.CreatePlaylistRequest value) => value.writeToBuffer(),
          $0.Playlist.fromBuffer);
  static final _$listPlaylists =
      $grpc.ClientMethod<$0.Empty, $0.ListPlaylistsResponse>(
          '/carnine.MediaService/ListPlaylists',
          ($0.Empty value) => value.writeToBuffer(),
          $0.ListPlaylistsResponse.fromBuffer);
  static final _$addPlaylistEntry =
      $grpc.ClientMethod<$0.AddPlaylistEntryRequest, $0.PlaylistEntry>(
          '/carnine.MediaService/AddPlaylistEntry',
          ($0.AddPlaylistEntryRequest value) => value.writeToBuffer(),
          $0.PlaylistEntry.fromBuffer);
  static final _$getPlaylist =
      $grpc.ClientMethod<$0.GetPlaylistRequest, $0.Playlist>(
          '/carnine.MediaService/GetPlaylist',
          ($0.GetPlaylistRequest value) => value.writeToBuffer(),
          $0.Playlist.fromBuffer);
  static final _$streamPlayerEvents =
      $grpc.ClientMethod<$0.Empty, $0.PlayerEvent>(
          '/carnine.MediaService/StreamPlayerEvents',
          ($0.Empty value) => value.writeToBuffer(),
          $0.PlayerEvent.fromBuffer);
  static final _$getCoverArt =
      $grpc.ClientMethod<$0.GetCoverArtRequest, $0.GetCoverArtResponse>(
          '/carnine.MediaService/GetCoverArt',
          ($0.GetCoverArtRequest value) => value.writeToBuffer(),
          $0.GetCoverArtResponse.fromBuffer);
  static final _$setRepeatMode =
      $grpc.ClientMethod<$0.SetRepeatModeRequest, $0.CommandResponse>(
          '/carnine.MediaService/SetRepeatMode',
          ($0.SetRepeatModeRequest value) => value.writeToBuffer(),
          $0.CommandResponse.fromBuffer);
  static final _$setShuffleMode =
      $grpc.ClientMethod<$0.SetShuffleModeRequest, $0.CommandResponse>(
          '/carnine.MediaService/SetShuffleMode',
          ($0.SetShuffleModeRequest value) => value.writeToBuffer(),
          $0.CommandResponse.fromBuffer);
}

@$pb.GrpcServiceName('carnine.MediaService')
abstract class MediaServiceBase extends $grpc.Service {
  $core.String get $name => 'carnine.MediaService';

  MediaServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.ServiceVersion>(
        'GetServiceVersion',
        getServiceVersion_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.ServiceVersion value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PlayRequest, $0.CommandResponse>(
        'Play',
        play_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PlayRequest.fromBuffer(value),
        ($0.CommandResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.CommandResponse>(
        'Pause',
        pause_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.CommandResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.CommandResponse>(
        'Stop',
        stop_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.CommandResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.CommandResponse>(
        'Next',
        next_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.CommandResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.CommandResponse>(
        'Previous',
        previous_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.CommandResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.CommandResponse>(
        'RestartCurrentTrack',
        restartCurrentTrack_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.CommandResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.PlayQueueEntryRequest, $0.CommandResponse>(
            'PlayQueueEntry',
            playQueueEntry_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.PlayQueueEntryRequest.fromBuffer(value),
            ($0.CommandResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PlayPlaylistRequest, $0.CommandResponse>(
        'PlayPlaylist',
        playPlaylist_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.PlayPlaylistRequest.fromBuffer(value),
        ($0.CommandResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.PlayerState>(
        'GetPlayerState',
        getPlayerState_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.PlayerState value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SearchMediaRequest, $0.SearchMediaResponse>(
            'SearchMedia',
            searchMedia_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SearchMediaRequest.fromBuffer(value),
            ($0.SearchMediaResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ImportMusicVolumeRequest, $0.LibraryEvent>(
            'ImportMusicVolume',
            importMusicVolume_Pre,
            false,
            true,
            ($core.List<$core.int> value) =>
                $0.ImportMusicVolumeRequest.fromBuffer(value),
            ($0.LibraryEvent value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RescanMediaRequest, $0.LibraryEvent>(
        'RescanMedia',
        rescanMedia_Pre,
        false,
        true,
        ($core.List<$core.int> value) =>
            $0.RescanMediaRequest.fromBuffer(value),
        ($0.LibraryEvent value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.LibraryEvent>(
        'StreamLibraryEvents',
        streamLibraryEvents_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.LibraryEvent value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CreatePlaylistRequest, $0.Playlist>(
        'CreatePlaylist',
        createPlaylist_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreatePlaylistRequest.fromBuffer(value),
        ($0.Playlist value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.ListPlaylistsResponse>(
        'ListPlaylists',
        listPlaylists_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.ListPlaylistsResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.AddPlaylistEntryRequest, $0.PlaylistEntry>(
            'AddPlaylistEntry',
            addPlaylistEntry_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.AddPlaylistEntryRequest.fromBuffer(value),
            ($0.PlaylistEntry value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetPlaylistRequest, $0.Playlist>(
        'GetPlaylist',
        getPlaylist_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetPlaylistRequest.fromBuffer(value),
        ($0.Playlist value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.PlayerEvent>(
        'StreamPlayerEvents',
        streamPlayerEvents_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.PlayerEvent value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetCoverArtRequest, $0.GetCoverArtResponse>(
            'GetCoverArt',
            getCoverArt_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetCoverArtRequest.fromBuffer(value),
            ($0.GetCoverArtResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SetRepeatModeRequest, $0.CommandResponse>(
        'SetRepeatMode',
        setRepeatMode_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SetRepeatModeRequest.fromBuffer(value),
        ($0.CommandResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SetShuffleModeRequest, $0.CommandResponse>(
            'SetShuffleMode',
            setShuffleMode_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SetShuffleModeRequest.fromBuffer(value),
            ($0.CommandResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.ServiceVersion> getServiceVersion_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return getServiceVersion($call, await $request);
  }

  $async.Future<$0.ServiceVersion> getServiceVersion(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.CommandResponse> play_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.PlayRequest> $request) async {
    return play($call, await $request);
  }

  $async.Future<$0.CommandResponse> play(
      $grpc.ServiceCall call, $0.PlayRequest request);

  $async.Future<$0.CommandResponse> pause_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return pause($call, await $request);
  }

  $async.Future<$0.CommandResponse> pause(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.CommandResponse> stop_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return stop($call, await $request);
  }

  $async.Future<$0.CommandResponse> stop(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.CommandResponse> next_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return next($call, await $request);
  }

  $async.Future<$0.CommandResponse> next(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.CommandResponse> previous_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return previous($call, await $request);
  }

  $async.Future<$0.CommandResponse> previous(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.CommandResponse> restartCurrentTrack_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return restartCurrentTrack($call, await $request);
  }

  $async.Future<$0.CommandResponse> restartCurrentTrack(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.CommandResponse> playQueueEntry_Pre($grpc.ServiceCall $call,
      $async.Future<$0.PlayQueueEntryRequest> $request) async {
    return playQueueEntry($call, await $request);
  }

  $async.Future<$0.CommandResponse> playQueueEntry(
      $grpc.ServiceCall call, $0.PlayQueueEntryRequest request);

  $async.Future<$0.CommandResponse> playPlaylist_Pre($grpc.ServiceCall $call,
      $async.Future<$0.PlayPlaylistRequest> $request) async {
    return playPlaylist($call, await $request);
  }

  $async.Future<$0.CommandResponse> playPlaylist(
      $grpc.ServiceCall call, $0.PlayPlaylistRequest request);

  $async.Future<$0.PlayerState> getPlayerState_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return getPlayerState($call, await $request);
  }

  $async.Future<$0.PlayerState> getPlayerState(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.SearchMediaResponse> searchMedia_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SearchMediaRequest> $request) async {
    return searchMedia($call, await $request);
  }

  $async.Future<$0.SearchMediaResponse> searchMedia(
      $grpc.ServiceCall call, $0.SearchMediaRequest request);

  $async.Stream<$0.LibraryEvent> importMusicVolume_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ImportMusicVolumeRequest> $request) async* {
    yield* importMusicVolume($call, await $request);
  }

  $async.Stream<$0.LibraryEvent> importMusicVolume(
      $grpc.ServiceCall call, $0.ImportMusicVolumeRequest request);

  $async.Stream<$0.LibraryEvent> rescanMedia_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RescanMediaRequest> $request) async* {
    yield* rescanMedia($call, await $request);
  }

  $async.Stream<$0.LibraryEvent> rescanMedia(
      $grpc.ServiceCall call, $0.RescanMediaRequest request);

  $async.Stream<$0.LibraryEvent> streamLibraryEvents_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async* {
    yield* streamLibraryEvents($call, await $request);
  }

  $async.Stream<$0.LibraryEvent> streamLibraryEvents(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.Playlist> createPlaylist_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreatePlaylistRequest> $request) async {
    return createPlaylist($call, await $request);
  }

  $async.Future<$0.Playlist> createPlaylist(
      $grpc.ServiceCall call, $0.CreatePlaylistRequest request);

  $async.Future<$0.ListPlaylistsResponse> listPlaylists_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return listPlaylists($call, await $request);
  }

  $async.Future<$0.ListPlaylistsResponse> listPlaylists(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.PlaylistEntry> addPlaylistEntry_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AddPlaylistEntryRequest> $request) async {
    return addPlaylistEntry($call, await $request);
  }

  $async.Future<$0.PlaylistEntry> addPlaylistEntry(
      $grpc.ServiceCall call, $0.AddPlaylistEntryRequest request);

  $async.Future<$0.Playlist> getPlaylist_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetPlaylistRequest> $request) async {
    return getPlaylist($call, await $request);
  }

  $async.Future<$0.Playlist> getPlaylist(
      $grpc.ServiceCall call, $0.GetPlaylistRequest request);

  $async.Stream<$0.PlayerEvent> streamPlayerEvents_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async* {
    yield* streamPlayerEvents($call, await $request);
  }

  $async.Stream<$0.PlayerEvent> streamPlayerEvents(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.GetCoverArtResponse> getCoverArt_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetCoverArtRequest> $request) async {
    return getCoverArt($call, await $request);
  }

  $async.Future<$0.GetCoverArtResponse> getCoverArt(
      $grpc.ServiceCall call, $0.GetCoverArtRequest request);

  $async.Future<$0.CommandResponse> setRepeatMode_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SetRepeatModeRequest> $request) async {
    return setRepeatMode($call, await $request);
  }

  $async.Future<$0.CommandResponse> setRepeatMode(
      $grpc.ServiceCall call, $0.SetRepeatModeRequest request);

  $async.Future<$0.CommandResponse> setShuffleMode_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SetShuffleModeRequest> $request) async {
    return setShuffleMode($call, await $request);
  }

  $async.Future<$0.CommandResponse> setShuffleMode(
      $grpc.ServiceCall call, $0.SetShuffleModeRequest request);
}

@$pb.GrpcServiceName('carnine.AudioService')
class AudioServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AudioServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.ServiceVersion> getServiceVersion(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getServiceVersion, request, options: options);
  }

  $grpc.ResponseFuture<$0.VolumeResponse> getVolume(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getVolume, request, options: options);
  }

  $grpc.ResponseFuture<$0.VolumeResponse> setVolume(
    $0.SetVolumeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$setVolume, request, options: options);
  }

  $grpc.ResponseStream<$0.AudioEvent> streamAudioEvents(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$streamAudioEvents, $async.Stream.fromIterable([request]),
        options: options);
  }

  // method descriptors

  static final _$getServiceVersion =
      $grpc.ClientMethod<$0.Empty, $0.ServiceVersion>(
          '/carnine.AudioService/GetServiceVersion',
          ($0.Empty value) => value.writeToBuffer(),
          $0.ServiceVersion.fromBuffer);
  static final _$getVolume = $grpc.ClientMethod<$0.Empty, $0.VolumeResponse>(
      '/carnine.AudioService/GetVolume',
      ($0.Empty value) => value.writeToBuffer(),
      $0.VolumeResponse.fromBuffer);
  static final _$setVolume =
      $grpc.ClientMethod<$0.SetVolumeRequest, $0.VolumeResponse>(
          '/carnine.AudioService/SetVolume',
          ($0.SetVolumeRequest value) => value.writeToBuffer(),
          $0.VolumeResponse.fromBuffer);
  static final _$streamAudioEvents =
      $grpc.ClientMethod<$0.Empty, $0.AudioEvent>(
          '/carnine.AudioService/StreamAudioEvents',
          ($0.Empty value) => value.writeToBuffer(),
          $0.AudioEvent.fromBuffer);
}

@$pb.GrpcServiceName('carnine.AudioService')
abstract class AudioServiceBase extends $grpc.Service {
  $core.String get $name => 'carnine.AudioService';

  AudioServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.ServiceVersion>(
        'GetServiceVersion',
        getServiceVersion_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.ServiceVersion value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.VolumeResponse>(
        'GetVolume',
        getVolume_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.VolumeResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SetVolumeRequest, $0.VolumeResponse>(
        'SetVolume',
        setVolume_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SetVolumeRequest.fromBuffer(value),
        ($0.VolumeResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.AudioEvent>(
        'StreamAudioEvents',
        streamAudioEvents_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.AudioEvent value) => value.writeToBuffer()));
  }

  $async.Future<$0.ServiceVersion> getServiceVersion_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return getServiceVersion($call, await $request);
  }

  $async.Future<$0.ServiceVersion> getServiceVersion(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.VolumeResponse> getVolume_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return getVolume($call, await $request);
  }

  $async.Future<$0.VolumeResponse> getVolume(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.VolumeResponse> setVolume_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SetVolumeRequest> $request) async {
    return setVolume($call, await $request);
  }

  $async.Future<$0.VolumeResponse> setVolume(
      $grpc.ServiceCall call, $0.SetVolumeRequest request);

  $async.Stream<$0.AudioEvent> streamAudioEvents_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async* {
    yield* streamAudioEvents($call, await $request);
  }

  $async.Stream<$0.AudioEvent> streamAudioEvents(
      $grpc.ServiceCall call, $0.Empty request);
}

@$pb.GrpcServiceName('carnine.ConfigService')
class ConfigServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  ConfigServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.Configuration> getConfiguration(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getConfiguration, request, options: options);
  }

  $grpc.ResponseFuture<$0.ConfigurationResponse> updateConfiguration(
    $0.UpdateConfigurationRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateConfiguration, request, options: options);
  }

  // method descriptors

  static final _$getConfiguration =
      $grpc.ClientMethod<$0.Empty, $0.Configuration>(
          '/carnine.ConfigService/GetConfiguration',
          ($0.Empty value) => value.writeToBuffer(),
          $0.Configuration.fromBuffer);
  static final _$updateConfiguration = $grpc.ClientMethod<
          $0.UpdateConfigurationRequest, $0.ConfigurationResponse>(
      '/carnine.ConfigService/UpdateConfiguration',
      ($0.UpdateConfigurationRequest value) => value.writeToBuffer(),
      $0.ConfigurationResponse.fromBuffer);
}

@$pb.GrpcServiceName('carnine.ConfigService')
abstract class ConfigServiceBase extends $grpc.Service {
  $core.String get $name => 'carnine.ConfigService';

  ConfigServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.Configuration>(
        'GetConfiguration',
        getConfiguration_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.Configuration value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateConfigurationRequest,
            $0.ConfigurationResponse>(
        'UpdateConfiguration',
        updateConfiguration_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateConfigurationRequest.fromBuffer(value),
        ($0.ConfigurationResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.Configuration> getConfiguration_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return getConfiguration($call, await $request);
  }

  $async.Future<$0.Configuration> getConfiguration(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.ConfigurationResponse> updateConfiguration_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateConfigurationRequest> $request) async {
    return updateConfiguration($call, await $request);
  }

  $async.Future<$0.ConfigurationResponse> updateConfiguration(
      $grpc.ServiceCall call, $0.UpdateConfigurationRequest request);
}

@$pb.GrpcServiceName('carnine.SystemService')
class SystemServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  SystemServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.CommandResponse> reportUiReady(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$reportUiReady, request, options: options);
  }

  /// Latest sampled health snapshot. Answered from the sampler's cache, so
  /// calling this never triggers a read of /proc or /sys.
  $grpc.ResponseFuture<$0.SystemMetrics> getSystemMetrics(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getSystemMetrics, request, options: options);
  }

  /// Pushes a snapshot on every CPU sample (system.metrics_interval_seconds),
  /// starting with the current one.
  $grpc.ResponseStream<$0.SystemMetrics> streamSystemMetrics(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$streamSystemMetrics, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// What the UI keeps across restarts, stored in the media database next to
  /// the resume state. Unknown values are the UI's to ignore.
  $grpc.ResponseFuture<$0.UiState> getUiState(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getUiState, request, options: options);
  }

  $grpc.ResponseFuture<$0.CommandResponse> saveUiState(
    $0.UiState request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$saveUiState, request, options: options);
  }

  // method descriptors

  static final _$reportUiReady =
      $grpc.ClientMethod<$0.Empty, $0.CommandResponse>(
          '/carnine.SystemService/ReportUiReady',
          ($0.Empty value) => value.writeToBuffer(),
          $0.CommandResponse.fromBuffer);
  static final _$getSystemMetrics =
      $grpc.ClientMethod<$0.Empty, $0.SystemMetrics>(
          '/carnine.SystemService/GetSystemMetrics',
          ($0.Empty value) => value.writeToBuffer(),
          $0.SystemMetrics.fromBuffer);
  static final _$streamSystemMetrics =
      $grpc.ClientMethod<$0.Empty, $0.SystemMetrics>(
          '/carnine.SystemService/StreamSystemMetrics',
          ($0.Empty value) => value.writeToBuffer(),
          $0.SystemMetrics.fromBuffer);
  static final _$getUiState = $grpc.ClientMethod<$0.Empty, $0.UiState>(
      '/carnine.SystemService/GetUiState',
      ($0.Empty value) => value.writeToBuffer(),
      $0.UiState.fromBuffer);
  static final _$saveUiState =
      $grpc.ClientMethod<$0.UiState, $0.CommandResponse>(
          '/carnine.SystemService/SaveUiState',
          ($0.UiState value) => value.writeToBuffer(),
          $0.CommandResponse.fromBuffer);
}

@$pb.GrpcServiceName('carnine.SystemService')
abstract class SystemServiceBase extends $grpc.Service {
  $core.String get $name => 'carnine.SystemService';

  SystemServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.CommandResponse>(
        'ReportUiReady',
        reportUiReady_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.CommandResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.SystemMetrics>(
        'GetSystemMetrics',
        getSystemMetrics_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.SystemMetrics value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.SystemMetrics>(
        'StreamSystemMetrics',
        streamSystemMetrics_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.SystemMetrics value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.UiState>(
        'GetUiState',
        getUiState_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.UiState value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UiState, $0.CommandResponse>(
        'SaveUiState',
        saveUiState_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UiState.fromBuffer(value),
        ($0.CommandResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.CommandResponse> reportUiReady_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return reportUiReady($call, await $request);
  }

  $async.Future<$0.CommandResponse> reportUiReady(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.SystemMetrics> getSystemMetrics_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return getSystemMetrics($call, await $request);
  }

  $async.Future<$0.SystemMetrics> getSystemMetrics(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Stream<$0.SystemMetrics> streamSystemMetrics_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async* {
    yield* streamSystemMetrics($call, await $request);
  }

  $async.Stream<$0.SystemMetrics> streamSystemMetrics(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.UiState> getUiState_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return getUiState($call, await $request);
  }

  $async.Future<$0.UiState> getUiState(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.CommandResponse> saveUiState_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.UiState> $request) async {
    return saveUiState($call, await $request);
  }

  $async.Future<$0.CommandResponse> saveUiState(
      $grpc.ServiceCall call, $0.UiState request);
}

/// Routing, own position and place search for the navigation page (ADR-021).
/// Units are SI; failures are gRPC status codes: UNAVAILABLE (router down),
/// NOT_FOUND (no route, or no replay running), FAILED_PRECONDITION (no origin
/// given and no fix), INVALID_ARGUMENT (bad coordinates).
@$pb.GrpcServiceName('carnine.NavigationService')
class NavigationServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  NavigationServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.ServiceVersion> getServiceVersion(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getServiceVersion, request, options: options);
  }

  $grpc.ResponseFuture<$0.NavigationStatus> getNavigationStatus(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getNavigationStatus, request, options: options);
  }

  $grpc.ResponseFuture<$0.SearchPlacesResponse> searchPlaces(
    $0.SearchPlacesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$searchPlaces, request, options: options);
  }

  $grpc.ResponseFuture<$0.Route> computeRoute(
    $0.ComputeRouteRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$computeRoute, request, options: options);
  }

  /// The route of the running NMEA replay, map-matched against the recorded
  /// fixes, so position and route come from the same recording.
  $grpc.ResponseFuture<$0.Route> getReplayRoute(
    $0.GetReplayRouteRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getReplayRoute, request, options: options);
  }

  /// Fixes at the source's rate (1 Hz for NMEA), heading unsmoothed.
  $grpc.ResponseStream<$0.PositionFix> streamPositions(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$streamPositions, $async.Stream.fromIterable([request]),
        options: options);
  }

  // method descriptors

  static final _$getServiceVersion =
      $grpc.ClientMethod<$0.Empty, $0.ServiceVersion>(
          '/carnine.NavigationService/GetServiceVersion',
          ($0.Empty value) => value.writeToBuffer(),
          $0.ServiceVersion.fromBuffer);
  static final _$getNavigationStatus =
      $grpc.ClientMethod<$0.Empty, $0.NavigationStatus>(
          '/carnine.NavigationService/GetNavigationStatus',
          ($0.Empty value) => value.writeToBuffer(),
          $0.NavigationStatus.fromBuffer);
  static final _$searchPlaces =
      $grpc.ClientMethod<$0.SearchPlacesRequest, $0.SearchPlacesResponse>(
          '/carnine.NavigationService/SearchPlaces',
          ($0.SearchPlacesRequest value) => value.writeToBuffer(),
          $0.SearchPlacesResponse.fromBuffer);
  static final _$computeRoute =
      $grpc.ClientMethod<$0.ComputeRouteRequest, $0.Route>(
          '/carnine.NavigationService/ComputeRoute',
          ($0.ComputeRouteRequest value) => value.writeToBuffer(),
          $0.Route.fromBuffer);
  static final _$getReplayRoute =
      $grpc.ClientMethod<$0.GetReplayRouteRequest, $0.Route>(
          '/carnine.NavigationService/GetReplayRoute',
          ($0.GetReplayRouteRequest value) => value.writeToBuffer(),
          $0.Route.fromBuffer);
  static final _$streamPositions = $grpc.ClientMethod<$0.Empty, $0.PositionFix>(
      '/carnine.NavigationService/StreamPositions',
      ($0.Empty value) => value.writeToBuffer(),
      $0.PositionFix.fromBuffer);
}

@$pb.GrpcServiceName('carnine.NavigationService')
abstract class NavigationServiceBase extends $grpc.Service {
  $core.String get $name => 'carnine.NavigationService';

  NavigationServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.ServiceVersion>(
        'GetServiceVersion',
        getServiceVersion_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.ServiceVersion value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.NavigationStatus>(
        'GetNavigationStatus',
        getNavigationStatus_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.NavigationStatus value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SearchPlacesRequest, $0.SearchPlacesResponse>(
            'SearchPlaces',
            searchPlaces_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SearchPlacesRequest.fromBuffer(value),
            ($0.SearchPlacesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ComputeRouteRequest, $0.Route>(
        'ComputeRoute',
        computeRoute_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ComputeRouteRequest.fromBuffer(value),
        ($0.Route value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetReplayRouteRequest, $0.Route>(
        'GetReplayRoute',
        getReplayRoute_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetReplayRouteRequest.fromBuffer(value),
        ($0.Route value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.PositionFix>(
        'StreamPositions',
        streamPositions_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.PositionFix value) => value.writeToBuffer()));
  }

  $async.Future<$0.ServiceVersion> getServiceVersion_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return getServiceVersion($call, await $request);
  }

  $async.Future<$0.ServiceVersion> getServiceVersion(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.NavigationStatus> getNavigationStatus_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return getNavigationStatus($call, await $request);
  }

  $async.Future<$0.NavigationStatus> getNavigationStatus(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.SearchPlacesResponse> searchPlaces_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SearchPlacesRequest> $request) async {
    return searchPlaces($call, await $request);
  }

  $async.Future<$0.SearchPlacesResponse> searchPlaces(
      $grpc.ServiceCall call, $0.SearchPlacesRequest request);

  $async.Future<$0.Route> computeRoute_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ComputeRouteRequest> $request) async {
    return computeRoute($call, await $request);
  }

  $async.Future<$0.Route> computeRoute(
      $grpc.ServiceCall call, $0.ComputeRouteRequest request);

  $async.Future<$0.Route> getReplayRoute_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetReplayRouteRequest> $request) async {
    return getReplayRoute($call, await $request);
  }

  $async.Future<$0.Route> getReplayRoute(
      $grpc.ServiceCall call, $0.GetReplayRouteRequest request);

  $async.Stream<$0.PositionFix> streamPositions_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async* {
    yield* streamPositions($call, await $request);
  }

  $async.Stream<$0.PositionFix> streamPositions(
      $grpc.ServiceCall call, $0.Empty request);
}
