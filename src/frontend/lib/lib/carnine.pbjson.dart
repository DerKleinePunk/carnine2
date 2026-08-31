// This is a generated file - do not edit.
//
// Generated from carnine.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use canDataRequestDescriptor instead')
const CanDataRequest$json = {
  '1': 'CanDataRequest',
  '2': [
    {'1': 'sensor_id', '3': 1, '4': 1, '5': 9, '10': 'sensorId'},
  ],
};

/// Descriptor for `CanDataRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List canDataRequestDescriptor = $convert.base64Decode(
    'Cg5DYW5EYXRhUmVxdWVzdBIbCglzZW5zb3JfaWQYASABKAlSCHNlbnNvcklk');

@$core.Deprecated('Use canDataResponseDescriptor instead')
const CanDataResponse$json = {
  '1': 'CanDataResponse',
  '2': [
    {
      '1': 'data',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.carnine.CanData',
      '10': 'data'
    },
  ],
};

/// Descriptor for `CanDataResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List canDataResponseDescriptor = $convert.base64Decode(
    'Cg9DYW5EYXRhUmVzcG9uc2USJAoEZGF0YRgBIAMoCzIQLmNhcm5pbmUuQ2FuRGF0YVIEZGF0YQ'
    '==');

@$core.Deprecated('Use canDataDescriptor instead')
const CanData$json = {
  '1': 'CanData',
  '2': [
    {'1': 'sensor_id', '3': 1, '4': 1, '5': 9, '10': 'sensorId'},
    {'1': 'value', '3': 2, '4': 1, '5': 1, '10': 'value'},
    {'1': 'timestamp', '3': 3, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `CanData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List canDataDescriptor = $convert.base64Decode(
    'CgdDYW5EYXRhEhsKCXNlbnNvcl9pZBgBIAEoCVIIc2Vuc29ySWQSFAoFdmFsdWUYAiABKAFSBX'
    'ZhbHVlEhwKCXRpbWVzdGFtcBgDIAEoA1IJdGltZXN0YW1w');

@$core.Deprecated('Use commandResponseDescriptor instead')
const CommandResponse$json = {
  '1': 'CommandResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `CommandResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commandResponseDescriptor = $convert.base64Decode(
    'Cg9Db21tYW5kUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIYCgdtZXNzYWdlGA'
    'IgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use emptyDescriptor instead')
const Empty$json = {
  '1': 'Empty',
};

/// Descriptor for `Empty`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emptyDescriptor =
    $convert.base64Decode('CgVFbXB0eQ==');

@$core.Deprecated('Use serviceVersionDescriptor instead')
const ServiceVersion$json = {
  '1': 'ServiceVersion',
  '2': [
    {'1': 'major', '3': 1, '4': 1, '5': 13, '10': 'major'},
    {'1': 'minor', '3': 2, '4': 1, '5': 13, '10': 'minor'},
    {'1': 'patch', '3': 3, '4': 1, '5': 13, '10': 'patch'},
  ],
};

/// Descriptor for `ServiceVersion`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serviceVersionDescriptor = $convert.base64Decode(
    'Cg5TZXJ2aWNlVmVyc2lvbhIUCgVtYWpvchgBIAEoDVIFbWFqb3ISFAoFbWlub3IYAiABKA1SBW'
    '1pbm9yEhQKBXBhdGNoGAMgASgNUgVwYXRjaA==');

@$core.Deprecated('Use mediaIdDescriptor instead')
const MediaId$json = {
  '1': 'MediaId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 4, '10': 'value'},
  ],
};

/// Descriptor for `MediaId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mediaIdDescriptor =
    $convert.base64Decode('CgdNZWRpYUlkEhQKBXZhbHVlGAEgASgEUgV2YWx1ZQ==');

@$core.Deprecated('Use playlistEntryIdDescriptor instead')
const PlaylistEntryId$json = {
  '1': 'PlaylistEntryId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 4, '10': 'value'},
  ],
};

/// Descriptor for `PlaylistEntryId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playlistEntryIdDescriptor = $convert
    .base64Decode('Cg9QbGF5bGlzdEVudHJ5SWQSFAoFdmFsdWUYASABKARSBXZhbHVl');

@$core.Deprecated('Use queueEntryIdDescriptor instead')
const QueueEntryId$json = {
  '1': 'QueueEntryId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 4, '10': 'value'},
  ],
};

/// Descriptor for `QueueEntryId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List queueEntryIdDescriptor =
    $convert.base64Decode('CgxRdWV1ZUVudHJ5SWQSFAoFdmFsdWUYASABKARSBXZhbHVl');

@$core.Deprecated('Use sourceIdDescriptor instead')
const SourceId$json = {
  '1': 'SourceId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 4, '10': 'value'},
  ],
};

/// Descriptor for `SourceId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sourceIdDescriptor =
    $convert.base64Decode('CghTb3VyY2VJZBIUCgV2YWx1ZRgBIAEoBFIFdmFsdWU=');

@$core.Deprecated('Use scanIdDescriptor instead')
const ScanId$json = {
  '1': 'ScanId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 4, '10': 'value'},
  ],
};

/// Descriptor for `ScanId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scanIdDescriptor =
    $convert.base64Decode('CgZTY2FuSWQSFAoFdmFsdWUYASABKARSBXZhbHVl');

@$core.Deprecated('Use playRequestDescriptor instead')
const PlayRequest$json = {
  '1': 'PlayRequest',
  '2': [
    {'1': 'media_path', '3': 1, '4': 1, '5': 9, '10': 'mediaPath'},
  ],
};

/// Descriptor for `PlayRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playRequestDescriptor = $convert.base64Decode(
    'CgtQbGF5UmVxdWVzdBIdCgptZWRpYV9wYXRoGAEgASgJUgltZWRpYVBhdGg=');

@$core.Deprecated('Use searchMediaRequestDescriptor instead')
const SearchMediaRequest$json = {
  '1': 'SearchMediaRequest',
  '2': [
    {'1': 'query', '3': 1, '4': 1, '5': 9, '10': 'query'},
  ],
};

/// Descriptor for `SearchMediaRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchMediaRequestDescriptor = $convert
    .base64Decode('ChJTZWFyY2hNZWRpYVJlcXVlc3QSFAoFcXVlcnkYASABKAlSBXF1ZXJ5');

@$core.Deprecated('Use searchMediaResponseDescriptor instead')
const SearchMediaResponse$json = {
  '1': 'SearchMediaResponse',
  '2': [
    {
      '1': 'items',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.carnine.MediaItem',
      '10': 'items'
    },
  ],
};

/// Descriptor for `SearchMediaResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchMediaResponseDescriptor = $convert.base64Decode(
    'ChNTZWFyY2hNZWRpYVJlc3BvbnNlEigKBWl0ZW1zGAEgAygLMhIuY2FybmluZS5NZWRpYUl0ZW'
    '1SBWl0ZW1z');

@$core.Deprecated('Use rescanMediaRequestDescriptor instead')
const RescanMediaRequest$json = {
  '1': 'RescanMediaRequest',
};

/// Descriptor for `RescanMediaRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rescanMediaRequestDescriptor =
    $convert.base64Decode('ChJSZXNjYW5NZWRpYVJlcXVlc3Q=');

@$core.Deprecated('Use libraryEventDescriptor instead')
const LibraryEvent$json = {
  '1': 'LibraryEvent',
  '2': [
    {'1': 'event', '3': 1, '4': 1, '5': 9, '10': 'event'},
    {'1': 'scan_id', '3': 2, '4': 1, '5': 4, '10': 'scanId'},
    {'1': 'processed', '3': 3, '4': 1, '5': 4, '10': 'processed'},
    {'1': 'imported', '3': 4, '4': 1, '5': 4, '10': 'imported'},
    {'1': 'path', '3': 5, '4': 1, '5': 9, '10': 'path'},
    {'1': 'message', '3': 6, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `LibraryEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List libraryEventDescriptor = $convert.base64Decode(
    'CgxMaWJyYXJ5RXZlbnQSFAoFZXZlbnQYASABKAlSBWV2ZW50EhcKB3NjYW5faWQYAiABKARSBn'
    'NjYW5JZBIcCglwcm9jZXNzZWQYAyABKARSCXByb2Nlc3NlZBIaCghpbXBvcnRlZBgEIAEoBFII'
    'aW1wb3J0ZWQSEgoEcGF0aBgFIAEoCVIEcGF0aBIYCgdtZXNzYWdlGAYgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use mediaItemDescriptor instead')
const MediaItem$json = {
  '1': 'MediaItem',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 4, '10': 'id'},
    {'1': 'source_id', '3': 2, '4': 1, '5': 4, '10': 'sourceId'},
    {'1': 'path', '3': 3, '4': 1, '5': 9, '10': 'path'},
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {'1': 'artist', '3': 5, '4': 1, '5': 9, '10': 'artist'},
    {'1': 'duration_ms', '3': 6, '4': 1, '5': 3, '10': 'durationMs'},
    {'1': 'status', '3': 7, '4': 1, '5': 9, '10': 'status'},
  ],
};

/// Descriptor for `MediaItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mediaItemDescriptor = $convert.base64Decode(
    'CglNZWRpYUl0ZW0SDgoCaWQYASABKARSAmlkEhsKCXNvdXJjZV9pZBgCIAEoBFIIc291cmNlSW'
    'QSEgoEcGF0aBgDIAEoCVIEcGF0aBIUCgV0aXRsZRgEIAEoCVIFdGl0bGUSFgoGYXJ0aXN0GAUg'
    'ASgJUgZhcnRpc3QSHwoLZHVyYXRpb25fbXMYBiABKANSCmR1cmF0aW9uTXMSFgoGc3RhdHVzGA'
    'cgASgJUgZzdGF0dXM=');

@$core.Deprecated('Use playlistDescriptor instead')
const Playlist$json = {
  '1': 'Playlist',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 4, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'entries',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.carnine.PlaylistEntry',
      '10': 'entries'
    },
  ],
};

/// Descriptor for `Playlist`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playlistDescriptor = $convert.base64Decode(
    'CghQbGF5bGlzdBIOCgJpZBgBIAEoBFICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIwCgdlbnRyaW'
    'VzGAMgAygLMhYuY2FybmluZS5QbGF5bGlzdEVudHJ5UgdlbnRyaWVz');

@$core.Deprecated('Use playlistEntryDescriptor instead')
const PlaylistEntry$json = {
  '1': 'PlaylistEntry',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 4, '10': 'id'},
    {'1': 'playlist_id', '3': 2, '4': 1, '5': 4, '10': 'playlistId'},
    {'1': 'media_id', '3': 3, '4': 1, '5': 4, '10': 'mediaId'},
    {'1': 'position', '3': 4, '4': 1, '5': 4, '10': 'position'},
  ],
};

/// Descriptor for `PlaylistEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playlistEntryDescriptor = $convert.base64Decode(
    'Cg1QbGF5bGlzdEVudHJ5Eg4KAmlkGAEgASgEUgJpZBIfCgtwbGF5bGlzdF9pZBgCIAEoBFIKcG'
    'xheWxpc3RJZBIZCghtZWRpYV9pZBgDIAEoBFIHbWVkaWFJZBIaCghwb3NpdGlvbhgEIAEoBFII'
    'cG9zaXRpb24=');

@$core.Deprecated('Use playPlaylistRequestDescriptor instead')
const PlayPlaylistRequest$json = {
  '1': 'PlayPlaylistRequest',
  '2': [
    {'1': 'playlist_id', '3': 1, '4': 1, '5': 4, '10': 'playlistId'},
  ],
};

/// Descriptor for `PlayPlaylistRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playPlaylistRequestDescriptor = $convert.base64Decode(
    'ChNQbGF5UGxheWxpc3RSZXF1ZXN0Eh8KC3BsYXlsaXN0X2lkGAEgASgEUgpwbGF5bGlzdElk');

@$core.Deprecated('Use createPlaylistRequestDescriptor instead')
const CreatePlaylistRequest$json = {
  '1': 'CreatePlaylistRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `CreatePlaylistRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createPlaylistRequestDescriptor =
    $convert.base64Decode(
        'ChVDcmVhdGVQbGF5bGlzdFJlcXVlc3QSEgoEbmFtZRgBIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use listPlaylistsResponseDescriptor instead')
const ListPlaylistsResponse$json = {
  '1': 'ListPlaylistsResponse',
  '2': [
    {
      '1': 'playlists',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.carnine.Playlist',
      '10': 'playlists'
    },
  ],
};

/// Descriptor for `ListPlaylistsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listPlaylistsResponseDescriptor = $convert.base64Decode(
    'ChVMaXN0UGxheWxpc3RzUmVzcG9uc2USLwoJcGxheWxpc3RzGAEgAygLMhEuY2FybmluZS5QbG'
    'F5bGlzdFIJcGxheWxpc3Rz');

@$core.Deprecated('Use addPlaylistEntryRequestDescriptor instead')
const AddPlaylistEntryRequest$json = {
  '1': 'AddPlaylistEntryRequest',
  '2': [
    {'1': 'playlist_id', '3': 1, '4': 1, '5': 4, '10': 'playlistId'},
    {'1': 'media_id', '3': 2, '4': 1, '5': 4, '10': 'mediaId'},
  ],
};

/// Descriptor for `AddPlaylistEntryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addPlaylistEntryRequestDescriptor =
    $convert.base64Decode(
        'ChdBZGRQbGF5bGlzdEVudHJ5UmVxdWVzdBIfCgtwbGF5bGlzdF9pZBgBIAEoBFIKcGxheWxpc3'
        'RJZBIZCghtZWRpYV9pZBgCIAEoBFIHbWVkaWFJZA==');

@$core.Deprecated('Use getPlaylistRequestDescriptor instead')
const GetPlaylistRequest$json = {
  '1': 'GetPlaylistRequest',
  '2': [
    {'1': 'playlist_id', '3': 1, '4': 1, '5': 4, '10': 'playlistId'},
  ],
};

/// Descriptor for `GetPlaylistRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPlaylistRequestDescriptor = $convert.base64Decode(
    'ChJHZXRQbGF5bGlzdFJlcXVlc3QSHwoLcGxheWxpc3RfaWQYASABKARSCnBsYXlsaXN0SWQ=');

@$core.Deprecated('Use playerStateDescriptor instead')
const PlayerState$json = {
  '1': 'PlayerState',
  '2': [
    {'1': 'status', '3': 1, '4': 1, '5': 9, '10': 'status'},
    {'1': 'media_path', '3': 2, '4': 1, '5': 9, '10': 'mediaPath'},
    {'1': 'position_ms', '3': 3, '4': 1, '5': 3, '10': 'positionMs'},
    {'1': 'duration_ms', '3': 4, '4': 1, '5': 3, '10': 'durationMs'},
    {'1': 'playlist_id', '3': 5, '4': 1, '5': 4, '10': 'playlistId'},
  ],
};

/// Descriptor for `PlayerState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerStateDescriptor = $convert.base64Decode(
    'CgtQbGF5ZXJTdGF0ZRIWCgZzdGF0dXMYASABKAlSBnN0YXR1cxIdCgptZWRpYV9wYXRoGAIgAS'
    'gJUgltZWRpYVBhdGgSHwoLcG9zaXRpb25fbXMYAyABKANSCnBvc2l0aW9uTXMSHwoLZHVyYXRp'
    'b25fbXMYBCABKANSCmR1cmF0aW9uTXMSHwoLcGxheWxpc3RfaWQYBSABKARSCnBsYXlsaXN0SW'
    'Q=');

@$core.Deprecated('Use playerEventDescriptor instead')
const PlayerEvent$json = {
  '1': 'PlayerEvent',
  '2': [
    {'1': 'event', '3': 1, '4': 1, '5': 9, '10': 'event'},
    {
      '1': 'state',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.carnine.PlayerState',
      '10': 'state'
    },
    {'1': 'message', '3': 3, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `PlayerEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerEventDescriptor = $convert.base64Decode(
    'CgtQbGF5ZXJFdmVudBIUCgVldmVudBgBIAEoCVIFZXZlbnQSKgoFc3RhdGUYAiABKAsyFC5jYX'
    'JuaW5lLlBsYXllclN0YXRlUgVzdGF0ZRIYCgdtZXNzYWdlGAMgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use audioEventDescriptor instead')
const AudioEvent$json = {
  '1': 'AudioEvent',
  '2': [
    {'1': 'event', '3': 1, '4': 1, '5': 9, '10': 'event'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `AudioEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List audioEventDescriptor = $convert.base64Decode(
    'CgpBdWRpb0V2ZW50EhQKBWV2ZW50GAEgASgJUgVldmVudBIYCgdtZXNzYWdlGAIgASgJUgdtZX'
    'NzYWdl');

@$core.Deprecated('Use configurationDescriptor instead')
const Configuration$json = {
  '1': 'Configuration',
  '2': [
    {'1': 'server_address', '3': 1, '4': 1, '5': 9, '10': 'serverAddress'},
    {'1': 'database_path', '3': 2, '4': 1, '5': 9, '10': 'databasePath'},
    {'1': 'media_folders', '3': 3, '4': 3, '5': 9, '10': 'mediaFolders'},
    {
      '1': 'supported_formats',
      '3': 4,
      '4': 3,
      '5': 9,
      '10': 'supportedFormats'
    },
    {'1': 'rescan_on_start', '3': 5, '4': 1, '5': 8, '10': 'rescanOnStart'},
    {'1': 'resume_mode', '3': 6, '4': 1, '5': 9, '10': 'resumeMode'},
    {'1': 'audio_backend', '3': 7, '4': 1, '5': 9, '10': 'audioBackend'},
    {'1': 'audio_device', '3': 8, '4': 1, '5': 9, '10': 'audioDevice'},
    {'1': 'sample_rate', '3': 9, '4': 1, '5': 13, '10': 'sampleRate'},
    {'1': 'channels', '3': 10, '4': 1, '5': 13, '10': 'channels'},
    {
      '1': 'navigation_interrupt',
      '3': 11,
      '4': 1,
      '5': 9,
      '10': 'navigationInterrupt'
    },
    {'1': 'log_directory', '3': 12, '4': 1, '5': 9, '10': 'logDirectory'},
    {'1': 'log_level', '3': 13, '4': 1, '5': 9, '10': 'logLevel'},
  ],
};

/// Descriptor for `Configuration`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List configurationDescriptor = $convert.base64Decode(
    'Cg1Db25maWd1cmF0aW9uEiUKDnNlcnZlcl9hZGRyZXNzGAEgASgJUg1zZXJ2ZXJBZGRyZXNzEi'
    'MKDWRhdGFiYXNlX3BhdGgYAiABKAlSDGRhdGFiYXNlUGF0aBIjCg1tZWRpYV9mb2xkZXJzGAMg'
    'AygJUgxtZWRpYUZvbGRlcnMSKwoRc3VwcG9ydGVkX2Zvcm1hdHMYBCADKAlSEHN1cHBvcnRlZE'
    'Zvcm1hdHMSJgoPcmVzY2FuX29uX3N0YXJ0GAUgASgIUg1yZXNjYW5PblN0YXJ0Eh8KC3Jlc3Vt'
    'ZV9tb2RlGAYgASgJUgpyZXN1bWVNb2RlEiMKDWF1ZGlvX2JhY2tlbmQYByABKAlSDGF1ZGlvQm'
    'Fja2VuZBIhCgxhdWRpb19kZXZpY2UYCCABKAlSC2F1ZGlvRGV2aWNlEh8KC3NhbXBsZV9yYXRl'
    'GAkgASgNUgpzYW1wbGVSYXRlEhoKCGNoYW5uZWxzGAogASgNUghjaGFubmVscxIxChRuYXZpZ2'
    'F0aW9uX2ludGVycnVwdBgLIAEoCVITbmF2aWdhdGlvbkludGVycnVwdBIjCg1sb2dfZGlyZWN0'
    'b3J5GAwgASgJUgxsb2dEaXJlY3RvcnkSGwoJbG9nX2xldmVsGA0gASgJUghsb2dMZXZlbA==');

@$core.Deprecated('Use updateConfigurationRequestDescriptor instead')
const UpdateConfigurationRequest$json = {
  '1': 'UpdateConfigurationRequest',
  '2': [
    {
      '1': 'configuration',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.carnine.Configuration',
      '10': 'configuration'
    },
  ],
};

/// Descriptor for `UpdateConfigurationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateConfigurationRequestDescriptor =
    $convert.base64Decode(
        'ChpVcGRhdGVDb25maWd1cmF0aW9uUmVxdWVzdBI8Cg1jb25maWd1cmF0aW9uGAEgASgLMhYuY2'
        'FybmluZS5Db25maWd1cmF0aW9uUg1jb25maWd1cmF0aW9u');

@$core.Deprecated('Use configurationResponseDescriptor instead')
const ConfigurationResponse$json = {
  '1': 'ConfigurationResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {
      '1': 'configuration',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.carnine.Configuration',
      '10': 'configuration'
    },
    {'1': 'restart_required', '3': 4, '4': 1, '5': 8, '10': 'restartRequired'},
  ],
};

/// Descriptor for `ConfigurationResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List configurationResponseDescriptor = $convert.base64Decode(
    'ChVDb25maWd1cmF0aW9uUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIYCgdtZX'
    'NzYWdlGAIgASgJUgdtZXNzYWdlEjwKDWNvbmZpZ3VyYXRpb24YAyABKAsyFi5jYXJuaW5lLkNv'
    'bmZpZ3VyYXRpb25SDWNvbmZpZ3VyYXRpb24SKQoQcmVzdGFydF9yZXF1aXJlZBgEIAEoCFIPcm'
    'VzdGFydFJlcXVpcmVk');
