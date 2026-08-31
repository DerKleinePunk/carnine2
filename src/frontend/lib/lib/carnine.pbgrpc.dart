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
