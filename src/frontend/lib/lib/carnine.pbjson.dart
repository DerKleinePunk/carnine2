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

@$core.Deprecated('Use libraryEventTypeDescriptor instead')
const LibraryEventType$json = {
  '1': 'LibraryEventType',
  '2': [
    {'1': 'LIBRARY_EVENT_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'LIBRARY_SCAN_STARTED', '2': 1},
    {'1': 'LIBRARY_PROGRESS', '2': 2},
    {'1': 'LIBRARY_ERROR', '2': 3},
    {'1': 'LIBRARY_SCAN_COMPLETED', '2': 4},
    {'1': 'LIBRARY_MUSIC_FOUND', '2': 5},
    {'1': 'LIBRARY_IMPORT_STARTED', '2': 6},
    {'1': 'LIBRARY_IMPORT_PROGRESS', '2': 7},
    {'1': 'LIBRARY_IMPORT_COMPLETED', '2': 8},
    {'1': 'PLAYLIST_CREATED', '2': 9},
    {'1': 'PLAYLIST_ENTRY_ADDED', '2': 10},
  ],
};

/// Descriptor for `LibraryEventType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List libraryEventTypeDescriptor = $convert.base64Decode(
    'ChBMaWJyYXJ5RXZlbnRUeXBlEiIKHkxJQlJBUllfRVZFTlRfVFlQRV9VTlNQRUNJRklFRBAAEh'
    'gKFExJQlJBUllfU0NBTl9TVEFSVEVEEAESFAoQTElCUkFSWV9QUk9HUkVTUxACEhEKDUxJQlJB'
    'UllfRVJST1IQAxIaChZMSUJSQVJZX1NDQU5fQ09NUExFVEVEEAQSFwoTTElCUkFSWV9NVVNJQ1'
    '9GT1VORBAFEhoKFkxJQlJBUllfSU1QT1JUX1NUQVJURUQQBhIbChdMSUJSQVJZX0lNUE9SVF9Q'
    'Uk9HUkVTUxAHEhwKGExJQlJBUllfSU1QT1JUX0NPTVBMRVRFRBAIEhQKEFBMQVlMSVNUX0NSRU'
    'FURUQQCRIYChRQTEFZTElTVF9FTlRSWV9BRERFRBAK');

@$core.Deprecated('Use playerEventTypeDescriptor instead')
const PlayerEventType$json = {
  '1': 'PlayerEventType',
  '2': [
    {'1': 'PLAYER_EVENT_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'PLAYER_SNAPSHOT', '2': 1},
    {'1': 'PLAYER_POSITION_CHANGED', '2': 2},
    {'1': 'PLAYER_PLAYBACK_STARTED', '2': 3},
    {'1': 'PLAYER_RESUMED', '2': 4},
    {'1': 'PLAYER_PAUSED', '2': 5},
    {'1': 'PLAYER_STOPPED', '2': 6},
    {'1': 'PLAYER_TRACK_CHANGED', '2': 7},
    {'1': 'PLAYER_ERROR', '2': 8},
    {'1': 'PLAYER_QUEUE_FINISHED', '2': 9},
  ],
};

/// Descriptor for `PlayerEventType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List playerEventTypeDescriptor = $convert.base64Decode(
    'Cg9QbGF5ZXJFdmVudFR5cGUSIQodUExBWUVSX0VWRU5UX1RZUEVfVU5TUEVDSUZJRUQQABITCg'
    '9QTEFZRVJfU05BUFNIT1QQARIbChdQTEFZRVJfUE9TSVRJT05fQ0hBTkdFRBACEhsKF1BMQVlF'
    'Ul9QTEFZQkFDS19TVEFSVEVEEAMSEgoOUExBWUVSX1JFU1VNRUQQBBIRCg1QTEFZRVJfUEFVU0'
    'VEEAUSEgoOUExBWUVSX1NUT1BQRUQQBhIYChRQTEFZRVJfVFJBQ0tfQ0hBTkdFRBAHEhAKDFBM'
    'QVlFUl9FUlJPUhAIEhkKFVBMQVlFUl9RVUVVRV9GSU5JU0hFRBAJ');

@$core.Deprecated('Use repeatModeDescriptor instead')
const RepeatMode$json = {
  '1': 'RepeatMode',
  '2': [
    {'1': 'REPEAT_MODE_UNSPECIFIED', '2': 0},
    {'1': 'REPEAT_OFF', '2': 1},
    {'1': 'REPEAT_QUEUE', '2': 2},
    {'1': 'REPEAT_TRACK', '2': 3},
  ],
};

/// Descriptor for `RepeatMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List repeatModeDescriptor = $convert.base64Decode(
    'CgpSZXBlYXRNb2RlEhsKF1JFUEVBVF9NT0RFX1VOU1BFQ0lGSUVEEAASDgoKUkVQRUFUX09GRh'
    'ABEhAKDFJFUEVBVF9RVUVVRRACEhAKDFJFUEVBVF9UUkFDSxAD');

@$core.Deprecated('Use audioEventTypeDescriptor instead')
const AudioEventType$json = {
  '1': 'AudioEventType',
  '2': [
    {'1': 'AUDIO_EVENT_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'AUDIO_READY', '2': 1},
    {'1': 'AUDIO_SOURCE_STARTED', '2': 2},
    {'1': 'AUDIO_SOURCE_PAUSE_REQUESTED', '2': 3},
    {'1': 'AUDIO_SOURCE_RESUME_REQUESTED', '2': 4},
    {'1': 'AUDIO_SOURCE_STOP_REQUESTED', '2': 5},
    {'1': 'AUDIO_DECODER_STOPPED', '2': 6},
    {'1': 'AUDIO_SOURCE_REMOVED', '2': 7},
    {'1': 'AUDIO_DEVICE_CHANGED', '2': 8},
    {'1': 'AUDIO_ERROR', '2': 9},
  ],
};

/// Descriptor for `AudioEventType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List audioEventTypeDescriptor = $convert.base64Decode(
    'Cg5BdWRpb0V2ZW50VHlwZRIgChxBVURJT19FVkVOVF9UWVBFX1VOU1BFQ0lGSUVEEAASDwoLQV'
    'VESU9fUkVBRFkQARIYChRBVURJT19TT1VSQ0VfU1RBUlRFRBACEiAKHEFVRElPX1NPVVJDRV9Q'
    'QVVTRV9SRVFVRVNURUQQAxIhCh1BVURJT19TT1VSQ0VfUkVTVU1FX1JFUVVFU1RFRBAEEh8KG0'
    'FVRElPX1NPVVJDRV9TVE9QX1JFUVVFU1RFRBAFEhkKFUFVRElPX0RFQ09ERVJfU1RPUFBFRBAG'
    'EhgKFEFVRElPX1NPVVJDRV9SRU1PVkVEEAcSGAoUQVVESU9fREVWSUNFX0NIQU5HRUQQCBIPCg'
    'tBVURJT19FUlJPUhAJ');

@$core.Deprecated('Use fixStateDescriptor instead')
const FixState$json = {
  '1': 'FixState',
  '2': [
    {'1': 'FIX_STATE_UNSPECIFIED', '2': 0},
    {'1': 'FIX_STATE_NO_FIX', '2': 1},
    {'1': 'FIX_STATE_FIX', '2': 2},
  ],
};

/// Descriptor for `FixState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List fixStateDescriptor = $convert.base64Decode(
    'CghGaXhTdGF0ZRIZChVGSVhfU1RBVEVfVU5TUEVDSUZJRUQQABIUChBGSVhfU1RBVEVfTk9fRk'
    'lYEAESEQoNRklYX1NUQVRFX0ZJWBAC');

@$core.Deprecated('Use positionSourceKindDescriptor instead')
const PositionSourceKind$json = {
  '1': 'PositionSourceKind',
  '2': [
    {'1': 'POSITION_SOURCE_KIND_UNSPECIFIED', '2': 0},
    {'1': 'POSITION_SOURCE_NONE', '2': 1},
    {'1': 'POSITION_SOURCE_SERIAL', '2': 2},
    {'1': 'POSITION_SOURCE_REPLAY', '2': 3},
  ],
};

/// Descriptor for `PositionSourceKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List positionSourceKindDescriptor = $convert.base64Decode(
    'ChJQb3NpdGlvblNvdXJjZUtpbmQSJAogUE9TSVRJT05fU09VUkNFX0tJTkRfVU5TUEVDSUZJRU'
    'QQABIYChRQT1NJVElPTl9TT1VSQ0VfTk9ORRABEhoKFlBPU0lUSU9OX1NPVVJDRV9TRVJJQUwQ'
    'AhIaChZQT1NJVElPTl9TT1VSQ0VfUkVQTEFZEAM=');

@$core.Deprecated('Use placeTypeDescriptor instead')
const PlaceType$json = {
  '1': 'PlaceType',
  '2': [
    {'1': 'PLACE_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'PLACE_TYPE_PLACE', '2': 1},
    {'1': 'PLACE_TYPE_POI', '2': 2},
    {'1': 'PLACE_TYPE_MOUNTAIN_PEAK', '2': 3},
    {'1': 'PLACE_TYPE_WATER_NAME', '2': 4},
    {'1': 'PLACE_TYPE_TRANSPORTATION_NAME', '2': 5},
  ],
};

/// Descriptor for `PlaceType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List placeTypeDescriptor = $convert.base64Decode(
    'CglQbGFjZVR5cGUSGgoWUExBQ0VfVFlQRV9VTlNQRUNJRklFRBAAEhQKEFBMQUNFX1RZUEVfUE'
    'xBQ0UQARISCg5QTEFDRV9UWVBFX1BPSRACEhwKGFBMQUNFX1RZUEVfTU9VTlRBSU5fUEVBSxAD'
    'EhkKFVBMQUNFX1RZUEVfV0FURVJfTkFNRRAEEiIKHlBMQUNFX1RZUEVfVFJBTlNQT1JUQVRJT0'
    '5fTkFNRRAF');

@$core.Deprecated('Use uiStateDescriptor instead')
const UiState$json = {
  '1': 'UiState',
  '2': [
    {'1': 'last_page', '3': 1, '4': 1, '5': 9, '10': 'lastPage'},
  ],
};

/// Descriptor for `UiState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uiStateDescriptor = $convert
    .base64Decode('CgdVaVN0YXRlEhsKCWxhc3RfcGFnZRgBIAEoCVIIbGFzdFBhZ2U=');

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

@$core.Deprecated('Use importMusicVolumeRequestDescriptor instead')
const ImportMusicVolumeRequest$json = {
  '1': 'ImportMusicVolumeRequest',
  '2': [
    {'1': 'source_path', '3': 1, '4': 1, '5': 9, '10': 'sourcePath'},
  ],
};

/// Descriptor for `ImportMusicVolumeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List importMusicVolumeRequestDescriptor =
    $convert.base64Decode(
        'ChhJbXBvcnRNdXNpY1ZvbHVtZVJlcXVlc3QSHwoLc291cmNlX3BhdGgYASABKAlSCnNvdXJjZV'
        'BhdGg=');

@$core.Deprecated('Use libraryEventDescriptor instead')
const LibraryEvent$json = {
  '1': 'LibraryEvent',
  '2': [
    {
      '1': 'event',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.carnine.LibraryEventType',
      '10': 'event'
    },
    {'1': 'scan_id', '3': 2, '4': 1, '5': 4, '10': 'scanId'},
    {'1': 'processed', '3': 3, '4': 1, '5': 4, '10': 'processed'},
    {'1': 'imported', '3': 4, '4': 1, '5': 4, '10': 'imported'},
    {'1': 'path', '3': 5, '4': 1, '5': 9, '10': 'path'},
    {'1': 'message', '3': 6, '4': 1, '5': 9, '10': 'message'},
    {'1': 'source_label', '3': 7, '4': 1, '5': 9, '10': 'sourceLabel'},
    {'1': 'source_path', '3': 8, '4': 1, '5': 9, '10': 'sourcePath'},
    {'1': 'matching_files', '3': 9, '4': 1, '5': 4, '10': 'matchingFiles'},
    {'1': 'playlist_id', '3': 10, '4': 1, '5': 4, '10': 'playlistId'},
    {'1': 'playlist_name', '3': 11, '4': 1, '5': 9, '10': 'playlistName'},
  ],
};

/// Descriptor for `LibraryEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List libraryEventDescriptor = $convert.base64Decode(
    'CgxMaWJyYXJ5RXZlbnQSLwoFZXZlbnQYASABKA4yGS5jYXJuaW5lLkxpYnJhcnlFdmVudFR5cG'
    'VSBWV2ZW50EhcKB3NjYW5faWQYAiABKARSBnNjYW5JZBIcCglwcm9jZXNzZWQYAyABKARSCXBy'
    'b2Nlc3NlZBIaCghpbXBvcnRlZBgEIAEoBFIIaW1wb3J0ZWQSEgoEcGF0aBgFIAEoCVIEcGF0aB'
    'IYCgdtZXNzYWdlGAYgASgJUgdtZXNzYWdlEiEKDHNvdXJjZV9sYWJlbBgHIAEoCVILc291cmNl'
    'TGFiZWwSHwoLc291cmNlX3BhdGgYCCABKAlSCnNvdXJjZVBhdGgSJQoObWF0Y2hpbmdfZmlsZX'
    'MYCSABKARSDW1hdGNoaW5nRmlsZXMSHwoLcGxheWxpc3RfaWQYCiABKARSCnBsYXlsaXN0SWQS'
    'IwoNcGxheWxpc3RfbmFtZRgLIAEoCVIMcGxheWxpc3ROYW1l');

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
    {'1': 'has_cover_art', '3': 8, '4': 1, '5': 8, '10': 'hasCoverArt'},
  ],
};

/// Descriptor for `MediaItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mediaItemDescriptor = $convert.base64Decode(
    'CglNZWRpYUl0ZW0SDgoCaWQYASABKARSAmlkEhsKCXNvdXJjZV9pZBgCIAEoBFIIc291cmNlSW'
    'QSEgoEcGF0aBgDIAEoCVIEcGF0aBIUCgV0aXRsZRgEIAEoCVIFdGl0bGUSFgoGYXJ0aXN0GAUg'
    'ASgJUgZhcnRpc3QSHwoLZHVyYXRpb25fbXMYBiABKANSCmR1cmF0aW9uTXMSFgoGc3RhdHVzGA'
    'cgASgJUgZzdGF0dXMSIgoNaGFzX2NvdmVyX2FydBgIIAEoCFILaGFzQ292ZXJBcnQ=');

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
    {'1': 'has_cover_art', '3': 4, '4': 1, '5': 8, '10': 'hasCoverArt'},
  ],
};

/// Descriptor for `Playlist`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playlistDescriptor = $convert.base64Decode(
    'CghQbGF5bGlzdBIOCgJpZBgBIAEoBFICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIwCgdlbnRyaW'
    'VzGAMgAygLMhYuY2FybmluZS5QbGF5bGlzdEVudHJ5UgdlbnRyaWVzEiIKDWhhc19jb3Zlcl9h'
    'cnQYBCABKAhSC2hhc0NvdmVyQXJ0');

@$core.Deprecated('Use getCoverArtRequestDescriptor instead')
const GetCoverArtRequest$json = {
  '1': 'GetCoverArtRequest',
  '2': [
    {'1': 'media_id', '3': 1, '4': 1, '5': 4, '9': 0, '10': 'mediaId'},
    {'1': 'playlist_id', '3': 2, '4': 1, '5': 4, '9': 0, '10': 'playlistId'},
  ],
  '8': [
    {'1': 'target'},
  ],
};

/// Descriptor for `GetCoverArtRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCoverArtRequestDescriptor = $convert.base64Decode(
    'ChJHZXRDb3ZlckFydFJlcXVlc3QSGwoIbWVkaWFfaWQYASABKARIAFIHbWVkaWFJZBIhCgtwbG'
    'F5bGlzdF9pZBgCIAEoBEgAUgpwbGF5bGlzdElkQggKBnRhcmdldA==');

@$core.Deprecated('Use getCoverArtResponseDescriptor instead')
const GetCoverArtResponse$json = {
  '1': 'GetCoverArtResponse',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
    {'1': 'mime_type', '3': 2, '4': 1, '5': 9, '10': 'mimeType'},
  ],
};

/// Descriptor for `GetCoverArtResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCoverArtResponseDescriptor = $convert.base64Decode(
    'ChNHZXRDb3ZlckFydFJlc3BvbnNlEhIKBGRhdGEYASABKAxSBGRhdGESGwoJbWltZV90eXBlGA'
    'IgASgJUghtaW1lVHlwZQ==');

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

@$core.Deprecated('Use playQueueEntryRequestDescriptor instead')
const PlayQueueEntryRequest$json = {
  '1': 'PlayQueueEntryRequest',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 13, '10': 'index'},
  ],
};

/// Descriptor for `PlayQueueEntryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playQueueEntryRequestDescriptor =
    $convert.base64Decode(
        'ChVQbGF5UXVldWVFbnRyeVJlcXVlc3QSFAoFaW5kZXgYASABKA1SBWluZGV4');

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
    {
      '1': 'repeat_mode',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.carnine.RepeatMode',
      '10': 'repeatMode'
    },
    {'1': 'shuffle_enabled', '3': 7, '4': 1, '5': 8, '10': 'shuffleEnabled'},
  ],
};

/// Descriptor for `PlayerState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerStateDescriptor = $convert.base64Decode(
    'CgtQbGF5ZXJTdGF0ZRIWCgZzdGF0dXMYASABKAlSBnN0YXR1cxIdCgptZWRpYV9wYXRoGAIgAS'
    'gJUgltZWRpYVBhdGgSHwoLcG9zaXRpb25fbXMYAyABKANSCnBvc2l0aW9uTXMSHwoLZHVyYXRp'
    'b25fbXMYBCABKANSCmR1cmF0aW9uTXMSHwoLcGxheWxpc3RfaWQYBSABKARSCnBsYXlsaXN0SW'
    'QSNAoLcmVwZWF0X21vZGUYBiABKA4yEy5jYXJuaW5lLlJlcGVhdE1vZGVSCnJlcGVhdE1vZGUS'
    'JwoPc2h1ZmZsZV9lbmFibGVkGAcgASgIUg5zaHVmZmxlRW5hYmxlZA==');

@$core.Deprecated('Use playerEventDescriptor instead')
const PlayerEvent$json = {
  '1': 'PlayerEvent',
  '2': [
    {
      '1': 'event',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.carnine.PlayerEventType',
      '10': 'event'
    },
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
    'CgtQbGF5ZXJFdmVudBIuCgVldmVudBgBIAEoDjIYLmNhcm5pbmUuUGxheWVyRXZlbnRUeXBlUg'
    'VldmVudBIqCgVzdGF0ZRgCIAEoCzIULmNhcm5pbmUuUGxheWVyU3RhdGVSBXN0YXRlEhgKB21l'
    'c3NhZ2UYAyABKAlSB21lc3NhZ2U=');

@$core.Deprecated('Use setRepeatModeRequestDescriptor instead')
const SetRepeatModeRequest$json = {
  '1': 'SetRepeatModeRequest',
  '2': [
    {
      '1': 'mode',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.carnine.RepeatMode',
      '10': 'mode'
    },
  ],
};

/// Descriptor for `SetRepeatModeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setRepeatModeRequestDescriptor = $convert.base64Decode(
    'ChRTZXRSZXBlYXRNb2RlUmVxdWVzdBInCgRtb2RlGAEgASgOMhMuY2FybmluZS5SZXBlYXRNb2'
    'RlUgRtb2Rl');

@$core.Deprecated('Use setShuffleModeRequestDescriptor instead')
const SetShuffleModeRequest$json = {
  '1': 'SetShuffleModeRequest',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
  ],
};

/// Descriptor for `SetShuffleModeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setShuffleModeRequestDescriptor =
    $convert.base64Decode(
        'ChVTZXRTaHVmZmxlTW9kZVJlcXVlc3QSGAoHZW5hYmxlZBgBIAEoCFIHZW5hYmxlZA==');

@$core.Deprecated('Use audioEventDescriptor instead')
const AudioEvent$json = {
  '1': 'AudioEvent',
  '2': [
    {
      '1': 'event',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.carnine.AudioEventType',
      '10': 'event'
    },
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `AudioEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List audioEventDescriptor = $convert.base64Decode(
    'CgpBdWRpb0V2ZW50Ei0KBWV2ZW50GAEgASgOMhcuY2FybmluZS5BdWRpb0V2ZW50VHlwZVIFZX'
    'ZlbnQSGAoHbWVzc2FnZRgCIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use setVolumeRequestDescriptor instead')
const SetVolumeRequest$json = {
  '1': 'SetVolumeRequest',
  '2': [
    {'1': 'percent', '3': 1, '4': 1, '5': 13, '10': 'percent'},
  ],
};

/// Descriptor for `SetVolumeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setVolumeRequestDescriptor = $convert.base64Decode(
    'ChBTZXRWb2x1bWVSZXF1ZXN0EhgKB3BlcmNlbnQYASABKA1SB3BlcmNlbnQ=');

@$core.Deprecated('Use volumeResponseDescriptor instead')
const VolumeResponse$json = {
  '1': 'VolumeResponse',
  '2': [
    {'1': 'percent', '3': 1, '4': 1, '5': 13, '10': 'percent'},
  ],
};

/// Descriptor for `VolumeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List volumeResponseDescriptor = $convert
    .base64Decode('Cg5Wb2x1bWVSZXNwb25zZRIYCgdwZXJjZW50GAEgASgNUgdwZXJjZW50');

@$core.Deprecated('Use configurationDescriptor instead')
const Configuration$json = {
  '1': 'Configuration',
  '2': [
    {'1': 'socket_path', '3': 1, '4': 1, '5': 9, '10': 'socketPath'},
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
    {
      '1': 'navigation_interrupt',
      '3': 11,
      '4': 1,
      '5': 9,
      '10': 'navigationInterrupt'
    },
    {'1': 'log_directory', '3': 12, '4': 1, '5': 9, '10': 'logDirectory'},
    {'1': 'log_level', '3': 13, '4': 1, '5': 9, '10': 'logLevel'},
    {'1': 'cover_cache_dir', '3': 14, '4': 1, '5': 9, '10': 'coverCacheDir'},
    {'1': 'tcp_address', '3': 15, '4': 1, '5': 9, '10': 'tcpAddress'},
    {'1': 'socket_mode', '3': 19, '4': 1, '5': 9, '10': 'socketMode'},
    {
      '1': 'metrics_interval_seconds',
      '3': 16,
      '4': 1,
      '5': 4,
      '10': 'metricsIntervalSeconds'
    },
    {
      '1': 'disk_metrics_interval_seconds',
      '3': 17,
      '4': 1,
      '5': 4,
      '10': 'diskMetricsIntervalSeconds'
    },
    {'1': 'disk_paths', '3': 18, '4': 3, '5': 9, '10': 'diskPaths'},
  ],
};

/// Descriptor for `Configuration`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List configurationDescriptor = $convert.base64Decode(
    'Cg1Db25maWd1cmF0aW9uEh8KC3NvY2tldF9wYXRoGAEgASgJUgpzb2NrZXRQYXRoEiMKDWRhdG'
    'FiYXNlX3BhdGgYAiABKAlSDGRhdGFiYXNlUGF0aBIjCg1tZWRpYV9mb2xkZXJzGAMgAygJUgxt'
    'ZWRpYUZvbGRlcnMSKwoRc3VwcG9ydGVkX2Zvcm1hdHMYBCADKAlSEHN1cHBvcnRlZEZvcm1hdH'
    'MSJgoPcmVzY2FuX29uX3N0YXJ0GAUgASgIUg1yZXNjYW5PblN0YXJ0Eh8KC3Jlc3VtZV9tb2Rl'
    'GAYgASgJUgpyZXN1bWVNb2RlEjEKFG5hdmlnYXRpb25faW50ZXJydXB0GAsgASgJUhNuYXZpZ2'
    'F0aW9uSW50ZXJydXB0EiMKDWxvZ19kaXJlY3RvcnkYDCABKAlSDGxvZ0RpcmVjdG9yeRIbCgls'
    'b2dfbGV2ZWwYDSABKAlSCGxvZ0xldmVsEiYKD2NvdmVyX2NhY2hlX2RpchgOIAEoCVINY292ZX'
    'JDYWNoZURpchIfCgt0Y3BfYWRkcmVzcxgPIAEoCVIKdGNwQWRkcmVzcxIfCgtzb2NrZXRfbW9k'
    'ZRgTIAEoCVIKc29ja2V0TW9kZRI4ChhtZXRyaWNzX2ludGVydmFsX3NlY29uZHMYECABKARSFm'
    '1ldHJpY3NJbnRlcnZhbFNlY29uZHMSQQodZGlza19tZXRyaWNzX2ludGVydmFsX3NlY29uZHMY'
    'ESABKARSGmRpc2tNZXRyaWNzSW50ZXJ2YWxTZWNvbmRzEh0KCmRpc2tfcGF0aHMYEiADKAlSCW'
    'Rpc2tQYXRocw==');

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

@$core.Deprecated('Use diskUsageDescriptor instead')
const DiskUsage$json = {
  '1': 'DiskUsage',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'mount_point', '3': 2, '4': 1, '5': 9, '10': 'mountPoint'},
    {'1': 'total_bytes', '3': 3, '4': 1, '5': 4, '10': 'totalBytes'},
    {'1': 'available_bytes', '3': 4, '4': 1, '5': 4, '10': 'availableBytes'},
    {'1': 'used_percent', '3': 5, '4': 1, '5': 1, '10': 'usedPercent'},
  ],
};

/// Descriptor for `DiskUsage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List diskUsageDescriptor = $convert.base64Decode(
    'CglEaXNrVXNhZ2USEgoEcGF0aBgBIAEoCVIEcGF0aBIfCgttb3VudF9wb2ludBgCIAEoCVIKbW'
    '91bnRQb2ludBIfCgt0b3RhbF9ieXRlcxgDIAEoBFIKdG90YWxCeXRlcxInCg9hdmFpbGFibGVf'
    'Ynl0ZXMYBCABKARSDmF2YWlsYWJsZUJ5dGVzEiEKDHVzZWRfcGVyY2VudBgFIAEoAVILdXNlZF'
    'BlcmNlbnQ=');

@$core.Deprecated('Use systemMetricsDescriptor instead')
const SystemMetrics$json = {
  '1': 'SystemMetrics',
  '2': [
    {
      '1': 'cpu_temperature_celsius',
      '3': 1,
      '4': 1,
      '5': 1,
      '9': 0,
      '10': 'cpuTemperatureCelsius',
      '17': true
    },
    {
      '1': 'cpu_usage_percent',
      '3': 2,
      '4': 1,
      '5': 1,
      '9': 1,
      '10': 'cpuUsagePercent',
      '17': true
    },
    {'1': 'load_average_1m', '3': 3, '4': 1, '5': 1, '10': 'loadAverage1m'},
    {'1': 'load_average_5m', '3': 4, '4': 1, '5': 1, '10': 'loadAverage5m'},
    {'1': 'load_average_15m', '3': 5, '4': 1, '5': 1, '10': 'loadAverage15m'},
    {'1': 'cpu_count', '3': 6, '4': 1, '5': 13, '10': 'cpuCount'},
    {'1': 'uptime_seconds', '3': 7, '4': 1, '5': 4, '10': 'uptimeSeconds'},
    {
      '1': 'sampled_at_unix_ms',
      '3': 8,
      '4': 1,
      '5': 3,
      '10': 'sampledAtUnixMs'
    },
    {
      '1': 'disks',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.carnine.DiskUsage',
      '10': 'disks'
    },
    {
      '1': 'disks_sampled_at_unix_ms',
      '3': 10,
      '4': 1,
      '5': 3,
      '10': 'disksSampledAtUnixMs'
    },
  ],
  '8': [
    {'1': '_cpu_temperature_celsius'},
    {'1': '_cpu_usage_percent'},
  ],
};

/// Descriptor for `SystemMetrics`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List systemMetricsDescriptor = $convert.base64Decode(
    'Cg1TeXN0ZW1NZXRyaWNzEjsKF2NwdV90ZW1wZXJhdHVyZV9jZWxzaXVzGAEgASgBSABSFWNwdV'
    'RlbXBlcmF0dXJlQ2Vsc2l1c4gBARIvChFjcHVfdXNhZ2VfcGVyY2VudBgCIAEoAUgBUg9jcHVV'
    'c2FnZVBlcmNlbnSIAQESJgoPbG9hZF9hdmVyYWdlXzFtGAMgASgBUg1sb2FkQXZlcmFnZTFtEi'
    'YKD2xvYWRfYXZlcmFnZV81bRgEIAEoAVINbG9hZEF2ZXJhZ2U1bRIoChBsb2FkX2F2ZXJhZ2Vf'
    'MTVtGAUgASgBUg5sb2FkQXZlcmFnZTE1bRIbCgljcHVfY291bnQYBiABKA1SCGNwdUNvdW50Ei'
    'UKDnVwdGltZV9zZWNvbmRzGAcgASgEUg11cHRpbWVTZWNvbmRzEisKEnNhbXBsZWRfYXRfdW5p'
    'eF9tcxgIIAEoA1IPc2FtcGxlZEF0VW5peE1zEigKBWRpc2tzGAkgAygLMhIuY2FybmluZS5EaX'
    'NrVXNhZ2VSBWRpc2tzEjYKGGRpc2tzX3NhbXBsZWRfYXRfdW5peF9tcxgKIAEoA1IUZGlza3NT'
    'YW1wbGVkQXRVbml4TXNCGgoYX2NwdV90ZW1wZXJhdHVyZV9jZWxzaXVzQhQKEl9jcHVfdXNhZ2'
    'VfcGVyY2VudA==');

@$core.Deprecated('Use latLonDescriptor instead')
const LatLon$json = {
  '1': 'LatLon',
  '2': [
    {'1': 'latitude', '3': 1, '4': 1, '5': 1, '10': 'latitude'},
    {'1': 'longitude', '3': 2, '4': 1, '5': 1, '10': 'longitude'},
  ],
};

/// Descriptor for `LatLon`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List latLonDescriptor = $convert.base64Decode(
    'CgZMYXRMb24SGgoIbGF0aXR1ZGUYASABKAFSCGxhdGl0dWRlEhwKCWxvbmdpdHVkZRgCIAEoAV'
    'IJbG9uZ2l0dWRl');

@$core.Deprecated('Use positionFixDescriptor instead')
const PositionFix$json = {
  '1': 'PositionFix',
  '2': [
    {
      '1': 'fix_state',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.carnine.FixState',
      '10': 'fixState'
    },
    {
      '1': 'location',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.carnine.LatLon',
      '10': 'location'
    },
    {
      '1': 'heading_degrees',
      '3': 3,
      '4': 1,
      '5': 1,
      '9': 0,
      '10': 'headingDegrees',
      '17': true
    },
    {
      '1': 'speed_mps',
      '3': 4,
      '4': 1,
      '5': 1,
      '9': 1,
      '10': 'speedMps',
      '17': true
    },
    {
      '1': 'accuracy_meters',
      '3': 5,
      '4': 1,
      '5': 1,
      '9': 2,
      '10': 'accuracyMeters',
      '17': true
    },
    {
      '1': 'timestamp_utc_ms',
      '3': 6,
      '4': 1,
      '5': 3,
      '9': 3,
      '10': 'timestampUtcMs',
      '17': true
    },
    {
      '1': 'source',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.carnine.PositionSourceKind',
      '10': 'source'
    },
  ],
  '8': [
    {'1': '_heading_degrees'},
    {'1': '_speed_mps'},
    {'1': '_accuracy_meters'},
    {'1': '_timestamp_utc_ms'},
  ],
};

/// Descriptor for `PositionFix`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List positionFixDescriptor = $convert.base64Decode(
    'CgtQb3NpdGlvbkZpeBIuCglmaXhfc3RhdGUYASABKA4yES5jYXJuaW5lLkZpeFN0YXRlUghmaX'
    'hTdGF0ZRIrCghsb2NhdGlvbhgCIAEoCzIPLmNhcm5pbmUuTGF0TG9uUghsb2NhdGlvbhIsCg9o'
    'ZWFkaW5nX2RlZ3JlZXMYAyABKAFIAFIOaGVhZGluZ0RlZ3JlZXOIAQESIAoJc3BlZWRfbXBzGA'
    'QgASgBSAFSCHNwZWVkTXBziAEBEiwKD2FjY3VyYWN5X21ldGVycxgFIAEoAUgCUg5hY2N1cmFj'
    'eU1ldGVyc4gBARItChB0aW1lc3RhbXBfdXRjX21zGAYgASgDSANSDnRpbWVzdGFtcFV0Y01ziA'
    'EBEjMKBnNvdXJjZRgHIAEoDjIbLmNhcm5pbmUuUG9zaXRpb25Tb3VyY2VLaW5kUgZzb3VyY2VC'
    'EgoQX2hlYWRpbmdfZGVncmVlc0IMCgpfc3BlZWRfbXBzQhIKEF9hY2N1cmFjeV9tZXRlcnNCEw'
    'oRX3RpbWVzdGFtcF91dGNfbXM=');

@$core.Deprecated('Use navigationStatusDescriptor instead')
const NavigationStatus$json = {
  '1': 'NavigationStatus',
  '2': [
    {
      '1': 'routing_available',
      '3': 1,
      '4': 1,
      '5': 8,
      '10': 'routingAvailable'
    },
    {
      '1': 'position_source',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.carnine.PositionSourceKind',
      '10': 'positionSource'
    },
    {
      '1': 'fix_state',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.carnine.FixState',
      '10': 'fixState'
    },
    {'1': 'map_region', '3': 4, '4': 1, '5': 9, '10': 'mapRegion'},
    {
      '1': 'track_recording_available',
      '3': 5,
      '4': 1,
      '5': 8,
      '10': 'trackRecordingAvailable'
    },
    {
      '1': 'track_recording_enabled',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'trackRecordingEnabled'
    },
    {'1': 'track_file', '3': 7, '4': 1, '5': 9, '10': 'trackFile'},
  ],
};

/// Descriptor for `NavigationStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List navigationStatusDescriptor = $convert.base64Decode(
    'ChBOYXZpZ2F0aW9uU3RhdHVzEisKEXJvdXRpbmdfYXZhaWxhYmxlGAEgASgIUhByb3V0aW5nQX'
    'ZhaWxhYmxlEkQKD3Bvc2l0aW9uX3NvdXJjZRgCIAEoDjIbLmNhcm5pbmUuUG9zaXRpb25Tb3Vy'
    'Y2VLaW5kUg5wb3NpdGlvblNvdXJjZRIuCglmaXhfc3RhdGUYAyABKA4yES5jYXJuaW5lLkZpeF'
    'N0YXRlUghmaXhTdGF0ZRIdCgptYXBfcmVnaW9uGAQgASgJUgltYXBSZWdpb24SOgoZdHJhY2tf'
    'cmVjb3JkaW5nX2F2YWlsYWJsZRgFIAEoCFIXdHJhY2tSZWNvcmRpbmdBdmFpbGFibGUSNgoXdH'
    'JhY2tfcmVjb3JkaW5nX2VuYWJsZWQYBiABKAhSFXRyYWNrUmVjb3JkaW5nRW5hYmxlZBIdCgp0'
    'cmFja19maWxlGAcgASgJUgl0cmFja0ZpbGU=');

@$core.Deprecated('Use setTrackRecordingRequestDescriptor instead')
const SetTrackRecordingRequest$json = {
  '1': 'SetTrackRecordingRequest',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
  ],
};

/// Descriptor for `SetTrackRecordingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setTrackRecordingRequestDescriptor =
    $convert.base64Decode(
        'ChhTZXRUcmFja1JlY29yZGluZ1JlcXVlc3QSGAoHZW5hYmxlZBgBIAEoCFIHZW5hYmxlZA==');

@$core.Deprecated('Use placeDescriptor instead')
const Place$json = {
  '1': 'Place',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'location',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.carnine.LatLon',
      '10': 'location'
    },
    {'1': 'zoom', '3': 3, '4': 1, '5': 13, '10': 'zoom'},
    {
      '1': 'type',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.carnine.PlaceType',
      '10': 'type'
    },
    {'1': 'detail', '3': 5, '4': 1, '5': 9, '9': 0, '10': 'detail', '17': true},
    {'1': 'area', '3': 6, '4': 1, '5': 9, '9': 1, '10': 'area', '17': true},
  ],
  '8': [
    {'1': '_detail'},
    {'1': '_area'},
  ],
};

/// Descriptor for `Place`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List placeDescriptor = $convert.base64Decode(
    'CgVQbGFjZRISCgRuYW1lGAEgASgJUgRuYW1lEisKCGxvY2F0aW9uGAIgASgLMg8uY2FybmluZS'
    '5MYXRMb25SCGxvY2F0aW9uEhIKBHpvb20YAyABKA1SBHpvb20SJgoEdHlwZRgEIAEoDjISLmNh'
    'cm5pbmUuUGxhY2VUeXBlUgR0eXBlEhsKBmRldGFpbBgFIAEoCUgAUgZkZXRhaWyIAQESFwoEYX'
    'JlYRgGIAEoCUgBUgRhcmVhiAEBQgkKB19kZXRhaWxCBwoFX2FyZWE=');

@$core.Deprecated('Use searchPlacesRequestDescriptor instead')
const SearchPlacesRequest$json = {
  '1': 'SearchPlacesRequest',
  '2': [
    {'1': 'query', '3': 1, '4': 1, '5': 9, '10': 'query'},
    {'1': 'limit', '3': 2, '4': 1, '5': 13, '10': 'limit'},
    {
      '1': 'near',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.carnine.LatLon',
      '9': 0,
      '10': 'near',
      '17': true
    },
  ],
  '8': [
    {'1': '_near'},
  ],
};

/// Descriptor for `SearchPlacesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchPlacesRequestDescriptor = $convert.base64Decode(
    'ChNTZWFyY2hQbGFjZXNSZXF1ZXN0EhQKBXF1ZXJ5GAEgASgJUgVxdWVyeRIUCgVsaW1pdBgCIA'
    'EoDVIFbGltaXQSKAoEbmVhchgDIAEoCzIPLmNhcm5pbmUuTGF0TG9uSABSBG5lYXKIAQFCBwoF'
    'X25lYXI=');

@$core.Deprecated('Use searchPlacesResponseDescriptor instead')
const SearchPlacesResponse$json = {
  '1': 'SearchPlacesResponse',
  '2': [
    {
      '1': 'places',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.carnine.Place',
      '10': 'places'
    },
  ],
};

/// Descriptor for `SearchPlacesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchPlacesResponseDescriptor = $convert.base64Decode(
    'ChRTZWFyY2hQbGFjZXNSZXNwb25zZRImCgZwbGFjZXMYASADKAsyDi5jYXJuaW5lLlBsYWNlUg'
    'ZwbGFjZXM=');

@$core.Deprecated('Use getLocationNameRequestDescriptor instead')
const GetLocationNameRequest$json = {
  '1': 'GetLocationNameRequest',
  '2': [
    {
      '1': 'position',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.carnine.LatLon',
      '9': 0,
      '10': 'position',
      '17': true
    },
  ],
  '8': [
    {'1': '_position'},
  ],
};

/// Descriptor for `GetLocationNameRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getLocationNameRequestDescriptor =
    $convert.base64Decode(
        'ChZHZXRMb2NhdGlvbk5hbWVSZXF1ZXN0EjAKCHBvc2l0aW9uGAEgASgLMg8uY2FybmluZS5MYX'
        'RMb25IAFIIcG9zaXRpb26IAQFCCwoJX3Bvc2l0aW9u');

@$core.Deprecated('Use locationNameDescriptor instead')
const LocationName$json = {
  '1': 'LocationName',
  '2': [
    {'1': 'street', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'street', '17': true},
    {
      '1': 'locality',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'locality',
      '17': true
    },
    {
      '1': 'district',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'district',
      '17': true
    },
  ],
  '8': [
    {'1': '_street'},
    {'1': '_locality'},
    {'1': '_district'},
  ],
};

/// Descriptor for `LocationName`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List locationNameDescriptor = $convert.base64Decode(
    'CgxMb2NhdGlvbk5hbWUSGwoGc3RyZWV0GAEgASgJSABSBnN0cmVldIgBARIfCghsb2NhbGl0eR'
    'gCIAEoCUgBUghsb2NhbGl0eYgBARIfCghkaXN0cmljdBgDIAEoCUgCUghkaXN0cmljdIgBAUIJ'
    'Cgdfc3RyZWV0QgsKCV9sb2NhbGl0eUILCglfZGlzdHJpY3Q=');

@$core.Deprecated('Use computeRouteRequestDescriptor instead')
const ComputeRouteRequest$json = {
  '1': 'ComputeRouteRequest',
  '2': [
    {
      '1': 'origin',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.carnine.LatLon',
      '9': 0,
      '10': 'origin',
      '17': true
    },
    {
      '1': 'destination',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.carnine.LatLon',
      '10': 'destination'
    },
    {
      '1': 'language',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'language',
      '17': true
    },
  ],
  '8': [
    {'1': '_origin'},
    {'1': '_language'},
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
};

/// Descriptor for `ComputeRouteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List computeRouteRequestDescriptor = $convert.base64Decode(
    'ChNDb21wdXRlUm91dGVSZXF1ZXN0EiwKBm9yaWdpbhgBIAEoCzIPLmNhcm5pbmUuTGF0TG9uSA'
    'BSBm9yaWdpbogBARIxCgtkZXN0aW5hdGlvbhgCIAEoCzIPLmNhcm5pbmUuTGF0TG9uUgtkZXN0'
    'aW5hdGlvbhIfCghsYW5ndWFnZRgEIAEoCUgBUghsYW5ndWFnZYgBAUIJCgdfb3JpZ2luQgsKCV'
    '9sYW5ndWFnZUoECAMQBA==');

@$core.Deprecated('Use getReplayRouteRequestDescriptor instead')
const GetReplayRouteRequest$json = {
  '1': 'GetReplayRouteRequest',
  '2': [
    {
      '1': 'language',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'language',
      '17': true
    },
  ],
  '8': [
    {'1': '_language'},
  ],
};

/// Descriptor for `GetReplayRouteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getReplayRouteRequestDescriptor = $convert.base64Decode(
    'ChVHZXRSZXBsYXlSb3V0ZVJlcXVlc3QSHwoIbGFuZ3VhZ2UYASABKAlIAFIIbGFuZ3VhZ2WIAQ'
    'FCCwoJX2xhbmd1YWdl');

@$core.Deprecated('Use maneuverDescriptor instead')
const Maneuver$json = {
  '1': 'Maneuver',
  '2': [
    {'1': 'instruction', '3': 1, '4': 1, '5': 9, '10': 'instruction'},
    {'1': 'length_meters', '3': 2, '4': 1, '5': 1, '10': 'lengthMeters'},
    {'1': 'time_seconds', '3': 3, '4': 1, '5': 1, '10': 'timeSeconds'},
    {'1': 'type', '3': 4, '4': 1, '5': 13, '10': 'type'},
    {
      '1': 'begin_shape_index',
      '3': 5,
      '4': 1,
      '5': 13,
      '10': 'beginShapeIndex'
    },
    {'1': 'street_names', '3': 6, '4': 3, '5': 9, '10': 'streetNames'},
  ],
};

/// Descriptor for `Maneuver`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List maneuverDescriptor = $convert.base64Decode(
    'CghNYW5ldXZlchIgCgtpbnN0cnVjdGlvbhgBIAEoCVILaW5zdHJ1Y3Rpb24SIwoNbGVuZ3RoX2'
    '1ldGVycxgCIAEoAVIMbGVuZ3RoTWV0ZXJzEiEKDHRpbWVfc2Vjb25kcxgDIAEoAVILdGltZVNl'
    'Y29uZHMSEgoEdHlwZRgEIAEoDVIEdHlwZRIqChFiZWdpbl9zaGFwZV9pbmRleBgFIAEoDVIPYm'
    'VnaW5TaGFwZUluZGV4EiEKDHN0cmVldF9uYW1lcxgGIAMoCVILc3RyZWV0TmFtZXM=');

@$core.Deprecated('Use routeDescriptor instead')
const Route$json = {
  '1': 'Route',
  '2': [
    {'1': 'route_id', '3': 1, '4': 1, '5': 9, '10': 'routeId'},
    {
      '1': 'geometry',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.carnine.LatLon',
      '10': 'geometry'
    },
    {'1': 'distance_meters', '3': 3, '4': 1, '5': 1, '10': 'distanceMeters'},
    {'1': 'duration_seconds', '3': 4, '4': 1, '5': 1, '10': 'durationSeconds'},
    {
      '1': 'maneuvers',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.carnine.Maneuver',
      '10': 'maneuvers'
    },
  ],
};

/// Descriptor for `Route`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List routeDescriptor = $convert.base64Decode(
    'CgVSb3V0ZRIZCghyb3V0ZV9pZBgBIAEoCVIHcm91dGVJZBIrCghnZW9tZXRyeRgCIAMoCzIPLm'
    'Nhcm5pbmUuTGF0TG9uUghnZW9tZXRyeRInCg9kaXN0YW5jZV9tZXRlcnMYAyABKAFSDmRpc3Rh'
    'bmNlTWV0ZXJzEikKEGR1cmF0aW9uX3NlY29uZHMYBCABKAFSD2R1cmF0aW9uU2Vjb25kcxIvCg'
    'ltYW5ldXZlcnMYBSADKAsyES5jYXJuaW5lLk1hbmV1dmVyUgltYW5ldXZlcnM=');
