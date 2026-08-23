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

@$core.Deprecated('Use playerStateDescriptor instead')
const PlayerState$json = {
  '1': 'PlayerState',
  '2': [
    {'1': 'status', '3': 1, '4': 1, '5': 9, '10': 'status'},
    {'1': 'media_path', '3': 2, '4': 1, '5': 9, '10': 'mediaPath'},
    {'1': 'position_ms', '3': 3, '4': 1, '5': 3, '10': 'positionMs'},
    {'1': 'duration_ms', '3': 4, '4': 1, '5': 3, '10': 'durationMs'},
  ],
};

/// Descriptor for `PlayerState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerStateDescriptor = $convert.base64Decode(
    'CgtQbGF5ZXJTdGF0ZRIWCgZzdGF0dXMYASABKAlSBnN0YXR1cxIdCgptZWRpYV9wYXRoGAIgAS'
    'gJUgltZWRpYVBhdGgSHwoLcG9zaXRpb25fbXMYAyABKANSCnBvc2l0aW9uTXMSHwoLZHVyYXRp'
    'b25fbXMYBCABKANSCmR1cmF0aW9uTXM=');

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
