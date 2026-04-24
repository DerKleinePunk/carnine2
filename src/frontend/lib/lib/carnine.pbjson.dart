// This is a generated file - do not edit.
//
// Generated from lib/carnine.proto.

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

@$core.Deprecated('Use commandRequestDescriptor instead')
const CommandRequest$json = {
  '1': 'CommandRequest',
  '2': [
    {'1': 'command', '3': 1, '4': 1, '5': 9, '10': 'command'},
    {'1': 'parameters', '3': 2, '4': 1, '5': 9, '10': 'parameters'},
  ],
};

/// Descriptor for `CommandRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commandRequestDescriptor = $convert.base64Decode(
    'Cg5Db21tYW5kUmVxdWVzdBIYCgdjb21tYW5kGAEgASgJUgdjb21tYW5kEh4KCnBhcmFtZXRlcn'
    'MYAiABKAlSCnBhcmFtZXRlcnM=');

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
