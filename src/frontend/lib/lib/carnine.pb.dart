// This is a generated file - do not edit.
//
// Generated from carnine.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class CanDataRequest extends $pb.GeneratedMessage {
  factory CanDataRequest({
    $core.String? sensorId,
  }) {
    final result = create();
    if (sensorId != null) result.sensorId = sensorId;
    return result;
  }

  CanDataRequest._();

  factory CanDataRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CanDataRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CanDataRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sensorId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CanDataRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CanDataRequest copyWith(void Function(CanDataRequest) updates) =>
      super.copyWith((message) => updates(message as CanDataRequest))
          as CanDataRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CanDataRequest create() => CanDataRequest._();
  @$core.override
  CanDataRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CanDataRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CanDataRequest>(create);
  static CanDataRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sensorId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sensorId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSensorId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSensorId() => $_clearField(1);
}

class CanDataResponse extends $pb.GeneratedMessage {
  factory CanDataResponse({
    $core.Iterable<CanData>? data,
  }) {
    final result = create();
    if (data != null) result.data.addAll(data);
    return result;
  }

  CanDataResponse._();

  factory CanDataResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CanDataResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CanDataResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..pPM<CanData>(1, _omitFieldNames ? '' : 'data', subBuilder: CanData.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CanDataResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CanDataResponse copyWith(void Function(CanDataResponse) updates) =>
      super.copyWith((message) => updates(message as CanDataResponse))
          as CanDataResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CanDataResponse create() => CanDataResponse._();
  @$core.override
  CanDataResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CanDataResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CanDataResponse>(create);
  static CanDataResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<CanData> get data => $_getList(0);
}

class CanData extends $pb.GeneratedMessage {
  factory CanData({
    $core.String? sensorId,
    $core.double? value,
    $fixnum.Int64? timestamp,
  }) {
    final result = create();
    if (sensorId != null) result.sensorId = sensorId;
    if (value != null) result.value = value;
    if (timestamp != null) result.timestamp = timestamp;
    return result;
  }

  CanData._();

  factory CanData.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CanData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CanData',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sensorId')
    ..aD(2, _omitFieldNames ? '' : 'value')
    ..aInt64(3, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CanData clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CanData copyWith(void Function(CanData) updates) =>
      super.copyWith((message) => updates(message as CanData)) as CanData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CanData create() => CanData._();
  @$core.override
  CanData createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CanData getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CanData>(create);
  static CanData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sensorId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sensorId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSensorId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSensorId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestamp => $_getI64(2);
  @$pb.TagNumber(3)
  set timestamp($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestamp() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestamp() => $_clearField(3);
}

class CommandResponse extends $pb.GeneratedMessage {
  factory CommandResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (message != null) result.message = message;
    return result;
  }

  CommandResponse._();

  factory CommandResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CommandResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CommandResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommandResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommandResponse copyWith(void Function(CommandResponse) updates) =>
      super.copyWith((message) => updates(message as CommandResponse))
          as CommandResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CommandResponse create() => CommandResponse._();
  @$core.override
  CommandResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CommandResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommandResponse>(create);
  static CommandResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class Empty extends $pb.GeneratedMessage {
  factory Empty() => create();

  Empty._();

  factory Empty.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Empty.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Empty',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty copyWith(void Function(Empty) updates) =>
      super.copyWith((message) => updates(message as Empty)) as Empty;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Empty create() => Empty._();
  @$core.override
  Empty createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Empty getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Empty>(create);
  static Empty? _defaultInstance;
}

class ServiceVersion extends $pb.GeneratedMessage {
  factory ServiceVersion({
    $core.int? major,
    $core.int? minor,
    $core.int? patch,
  }) {
    final result = create();
    if (major != null) result.major = major;
    if (minor != null) result.minor = minor;
    if (patch != null) result.patch = patch;
    return result;
  }

  ServiceVersion._();

  factory ServiceVersion.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServiceVersion.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServiceVersion',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'major', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'minor', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'patch', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServiceVersion clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServiceVersion copyWith(void Function(ServiceVersion) updates) =>
      super.copyWith((message) => updates(message as ServiceVersion))
          as ServiceVersion;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServiceVersion create() => ServiceVersion._();
  @$core.override
  ServiceVersion createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServiceVersion getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServiceVersion>(create);
  static ServiceVersion? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get major => $_getIZ(0);
  @$pb.TagNumber(1)
  set major($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMajor() => $_has(0);
  @$pb.TagNumber(1)
  void clearMajor() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get minor => $_getIZ(1);
  @$pb.TagNumber(2)
  set minor($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMinor() => $_has(1);
  @$pb.TagNumber(2)
  void clearMinor() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get patch => $_getIZ(2);
  @$pb.TagNumber(3)
  set patch($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPatch() => $_has(2);
  @$pb.TagNumber(3)
  void clearPatch() => $_clearField(3);
}

class MediaId extends $pb.GeneratedMessage {
  factory MediaId({
    $fixnum.Int64? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  MediaId._();

  factory MediaId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MediaId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaId copyWith(void Function(MediaId) updates) =>
      super.copyWith((message) => updates(message as MediaId)) as MediaId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MediaId create() => MediaId._();
  @$core.override
  MediaId createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MediaId getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MediaId>(create);
  static MediaId? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get value => $_getI64(0);
  @$pb.TagNumber(1)
  set value($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class PlaylistEntryId extends $pb.GeneratedMessage {
  factory PlaylistEntryId({
    $fixnum.Int64? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  PlaylistEntryId._();

  factory PlaylistEntryId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlaylistEntryId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlaylistEntryId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlaylistEntryId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlaylistEntryId copyWith(void Function(PlaylistEntryId) updates) =>
      super.copyWith((message) => updates(message as PlaylistEntryId))
          as PlaylistEntryId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlaylistEntryId create() => PlaylistEntryId._();
  @$core.override
  PlaylistEntryId createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlaylistEntryId getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlaylistEntryId>(create);
  static PlaylistEntryId? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get value => $_getI64(0);
  @$pb.TagNumber(1)
  set value($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class QueueEntryId extends $pb.GeneratedMessage {
  factory QueueEntryId({
    $fixnum.Int64? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  QueueEntryId._();

  factory QueueEntryId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QueueEntryId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QueueEntryId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QueueEntryId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QueueEntryId copyWith(void Function(QueueEntryId) updates) =>
      super.copyWith((message) => updates(message as QueueEntryId))
          as QueueEntryId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QueueEntryId create() => QueueEntryId._();
  @$core.override
  QueueEntryId createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QueueEntryId getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QueueEntryId>(create);
  static QueueEntryId? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get value => $_getI64(0);
  @$pb.TagNumber(1)
  set value($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class SourceId extends $pb.GeneratedMessage {
  factory SourceId({
    $fixnum.Int64? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  SourceId._();

  factory SourceId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SourceId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SourceId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SourceId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SourceId copyWith(void Function(SourceId) updates) =>
      super.copyWith((message) => updates(message as SourceId)) as SourceId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SourceId create() => SourceId._();
  @$core.override
  SourceId createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SourceId getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SourceId>(create);
  static SourceId? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get value => $_getI64(0);
  @$pb.TagNumber(1)
  set value($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class ScanId extends $pb.GeneratedMessage {
  factory ScanId({
    $fixnum.Int64? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  ScanId._();

  factory ScanId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ScanId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScanId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanId copyWith(void Function(ScanId) updates) =>
      super.copyWith((message) => updates(message as ScanId)) as ScanId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ScanId create() => ScanId._();
  @$core.override
  ScanId createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ScanId getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ScanId>(create);
  static ScanId? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get value => $_getI64(0);
  @$pb.TagNumber(1)
  set value($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class PlayRequest extends $pb.GeneratedMessage {
  factory PlayRequest({
    $core.String? mediaPath,
  }) {
    final result = create();
    if (mediaPath != null) result.mediaPath = mediaPath;
    return result;
  }

  PlayRequest._();

  factory PlayRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlayRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'mediaPath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayRequest copyWith(void Function(PlayRequest) updates) =>
      super.copyWith((message) => updates(message as PlayRequest))
          as PlayRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlayRequest create() => PlayRequest._();
  @$core.override
  PlayRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlayRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlayRequest>(create);
  static PlayRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get mediaPath => $_getSZ(0);
  @$pb.TagNumber(1)
  set mediaPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMediaPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearMediaPath() => $_clearField(1);
}

class SearchMediaRequest extends $pb.GeneratedMessage {
  factory SearchMediaRequest({
    $core.String? query,
  }) {
    final result = create();
    if (query != null) result.query = query;
    return result;
  }

  SearchMediaRequest._();

  factory SearchMediaRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchMediaRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchMediaRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'query')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchMediaRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchMediaRequest copyWith(void Function(SearchMediaRequest) updates) =>
      super.copyWith((message) => updates(message as SearchMediaRequest))
          as SearchMediaRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchMediaRequest create() => SearchMediaRequest._();
  @$core.override
  SearchMediaRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SearchMediaRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchMediaRequest>(create);
  static SearchMediaRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get query => $_getSZ(0);
  @$pb.TagNumber(1)
  set query($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuery() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuery() => $_clearField(1);
}

class SearchMediaResponse extends $pb.GeneratedMessage {
  factory SearchMediaResponse({
    $core.Iterable<MediaItem>? items,
  }) {
    final result = create();
    if (items != null) result.items.addAll(items);
    return result;
  }

  SearchMediaResponse._();

  factory SearchMediaResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchMediaResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchMediaResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..pPM<MediaItem>(1, _omitFieldNames ? '' : 'items',
        subBuilder: MediaItem.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchMediaResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchMediaResponse copyWith(void Function(SearchMediaResponse) updates) =>
      super.copyWith((message) => updates(message as SearchMediaResponse))
          as SearchMediaResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchMediaResponse create() => SearchMediaResponse._();
  @$core.override
  SearchMediaResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SearchMediaResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchMediaResponse>(create);
  static SearchMediaResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<MediaItem> get items => $_getList(0);
}

class RescanMediaRequest extends $pb.GeneratedMessage {
  factory RescanMediaRequest() => create();

  RescanMediaRequest._();

  factory RescanMediaRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RescanMediaRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RescanMediaRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RescanMediaRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RescanMediaRequest copyWith(void Function(RescanMediaRequest) updates) =>
      super.copyWith((message) => updates(message as RescanMediaRequest))
          as RescanMediaRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RescanMediaRequest create() => RescanMediaRequest._();
  @$core.override
  RescanMediaRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RescanMediaRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RescanMediaRequest>(create);
  static RescanMediaRequest? _defaultInstance;
}

class LibraryEvent extends $pb.GeneratedMessage {
  factory LibraryEvent({
    $core.String? event,
    $fixnum.Int64? scanId,
    $fixnum.Int64? processed,
    $fixnum.Int64? imported,
    $core.String? path,
    $core.String? message,
  }) {
    final result = create();
    if (event != null) result.event = event;
    if (scanId != null) result.scanId = scanId;
    if (processed != null) result.processed = processed;
    if (imported != null) result.imported = imported;
    if (path != null) result.path = path;
    if (message != null) result.message = message;
    return result;
  }

  LibraryEvent._();

  factory LibraryEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LibraryEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LibraryEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'event')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'scanId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'processed', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'imported', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(5, _omitFieldNames ? '' : 'path')
    ..aOS(6, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LibraryEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LibraryEvent copyWith(void Function(LibraryEvent) updates) =>
      super.copyWith((message) => updates(message as LibraryEvent))
          as LibraryEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LibraryEvent create() => LibraryEvent._();
  @$core.override
  LibraryEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LibraryEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LibraryEvent>(create);
  static LibraryEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get event => $_getSZ(0);
  @$pb.TagNumber(1)
  set event($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEvent() => $_has(0);
  @$pb.TagNumber(1)
  void clearEvent() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get scanId => $_getI64(1);
  @$pb.TagNumber(2)
  set scanId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasScanId() => $_has(1);
  @$pb.TagNumber(2)
  void clearScanId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get processed => $_getI64(2);
  @$pb.TagNumber(3)
  set processed($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProcessed() => $_has(2);
  @$pb.TagNumber(3)
  void clearProcessed() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get imported => $_getI64(3);
  @$pb.TagNumber(4)
  set imported($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasImported() => $_has(3);
  @$pb.TagNumber(4)
  void clearImported() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get path => $_getSZ(4);
  @$pb.TagNumber(5)
  set path($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPath() => $_has(4);
  @$pb.TagNumber(5)
  void clearPath() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get message => $_getSZ(5);
  @$pb.TagNumber(6)
  set message($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMessage() => $_has(5);
  @$pb.TagNumber(6)
  void clearMessage() => $_clearField(6);
}

class MediaItem extends $pb.GeneratedMessage {
  factory MediaItem({
    $fixnum.Int64? id,
    $fixnum.Int64? sourceId,
    $core.String? path,
    $core.String? title,
    $core.String? artist,
    $fixnum.Int64? durationMs,
    $core.String? status,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (sourceId != null) result.sourceId = sourceId;
    if (path != null) result.path = path;
    if (title != null) result.title = title;
    if (artist != null) result.artist = artist;
    if (durationMs != null) result.durationMs = durationMs;
    if (status != null) result.status = status;
    return result;
  }

  MediaItem._();

  factory MediaItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MediaItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'sourceId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(3, _omitFieldNames ? '' : 'path')
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aOS(5, _omitFieldNames ? '' : 'artist')
    ..aInt64(6, _omitFieldNames ? '' : 'durationMs')
    ..aOS(7, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaItem copyWith(void Function(MediaItem) updates) =>
      super.copyWith((message) => updates(message as MediaItem)) as MediaItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MediaItem create() => MediaItem._();
  @$core.override
  MediaItem createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MediaItem getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MediaItem>(create);
  static MediaItem? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get sourceId => $_getI64(1);
  @$pb.TagNumber(2)
  set sourceId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSourceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSourceId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get path => $_getSZ(2);
  @$pb.TagNumber(3)
  set path($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPath() => $_has(2);
  @$pb.TagNumber(3)
  void clearPath() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get artist => $_getSZ(4);
  @$pb.TagNumber(5)
  set artist($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasArtist() => $_has(4);
  @$pb.TagNumber(5)
  void clearArtist() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get durationMs => $_getI64(5);
  @$pb.TagNumber(6)
  set durationMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDurationMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearDurationMs() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get status => $_getSZ(6);
  @$pb.TagNumber(7)
  set status($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStatus() => $_has(6);
  @$pb.TagNumber(7)
  void clearStatus() => $_clearField(7);
}

class Playlist extends $pb.GeneratedMessage {
  factory Playlist({
    $fixnum.Int64? id,
    $core.String? name,
    $core.Iterable<PlaylistEntry>? entries,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (entries != null) result.entries.addAll(entries);
    return result;
  }

  Playlist._();

  factory Playlist.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Playlist.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Playlist',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..pPM<PlaylistEntry>(3, _omitFieldNames ? '' : 'entries',
        subBuilder: PlaylistEntry.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Playlist clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Playlist copyWith(void Function(Playlist) updates) =>
      super.copyWith((message) => updates(message as Playlist)) as Playlist;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Playlist create() => Playlist._();
  @$core.override
  Playlist createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Playlist getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Playlist>(create);
  static Playlist? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<PlaylistEntry> get entries => $_getList(2);
}

class PlaylistEntry extends $pb.GeneratedMessage {
  factory PlaylistEntry({
    $fixnum.Int64? id,
    $fixnum.Int64? playlistId,
    $fixnum.Int64? mediaId,
    $fixnum.Int64? position,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (playlistId != null) result.playlistId = playlistId;
    if (mediaId != null) result.mediaId = mediaId;
    if (position != null) result.position = position;
    return result;
  }

  PlaylistEntry._();

  factory PlaylistEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlaylistEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlaylistEntry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'playlistId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'mediaId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'position', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlaylistEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlaylistEntry copyWith(void Function(PlaylistEntry) updates) =>
      super.copyWith((message) => updates(message as PlaylistEntry))
          as PlaylistEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlaylistEntry create() => PlaylistEntry._();
  @$core.override
  PlaylistEntry createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlaylistEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlaylistEntry>(create);
  static PlaylistEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get playlistId => $_getI64(1);
  @$pb.TagNumber(2)
  set playlistId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlaylistId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlaylistId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get mediaId => $_getI64(2);
  @$pb.TagNumber(3)
  set mediaId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMediaId() => $_has(2);
  @$pb.TagNumber(3)
  void clearMediaId() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get position => $_getI64(3);
  @$pb.TagNumber(4)
  set position($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPosition() => $_has(3);
  @$pb.TagNumber(4)
  void clearPosition() => $_clearField(4);
}

class PlayPlaylistRequest extends $pb.GeneratedMessage {
  factory PlayPlaylistRequest({
    $fixnum.Int64? playlistId,
  }) {
    final result = create();
    if (playlistId != null) result.playlistId = playlistId;
    return result;
  }

  PlayPlaylistRequest._();

  factory PlayPlaylistRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlayPlaylistRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayPlaylistRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'playlistId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayPlaylistRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayPlaylistRequest copyWith(void Function(PlayPlaylistRequest) updates) =>
      super.copyWith((message) => updates(message as PlayPlaylistRequest))
          as PlayPlaylistRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlayPlaylistRequest create() => PlayPlaylistRequest._();
  @$core.override
  PlayPlaylistRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlayPlaylistRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlayPlaylistRequest>(create);
  static PlayPlaylistRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get playlistId => $_getI64(0);
  @$pb.TagNumber(1)
  set playlistId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlaylistId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlaylistId() => $_clearField(1);
}

class CreatePlaylistRequest extends $pb.GeneratedMessage {
  factory CreatePlaylistRequest({
    $core.String? name,
  }) {
    final result = create();
    if (name != null) result.name = name;
    return result;
  }

  CreatePlaylistRequest._();

  factory CreatePlaylistRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreatePlaylistRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreatePlaylistRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePlaylistRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePlaylistRequest copyWith(
          void Function(CreatePlaylistRequest) updates) =>
      super.copyWith((message) => updates(message as CreatePlaylistRequest))
          as CreatePlaylistRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreatePlaylistRequest create() => CreatePlaylistRequest._();
  @$core.override
  CreatePlaylistRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreatePlaylistRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreatePlaylistRequest>(create);
  static CreatePlaylistRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);
}

class ListPlaylistsResponse extends $pb.GeneratedMessage {
  factory ListPlaylistsResponse({
    $core.Iterable<Playlist>? playlists,
  }) {
    final result = create();
    if (playlists != null) result.playlists.addAll(playlists);
    return result;
  }

  ListPlaylistsResponse._();

  factory ListPlaylistsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListPlaylistsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListPlaylistsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..pPM<Playlist>(1, _omitFieldNames ? '' : 'playlists',
        subBuilder: Playlist.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPlaylistsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPlaylistsResponse copyWith(
          void Function(ListPlaylistsResponse) updates) =>
      super.copyWith((message) => updates(message as ListPlaylistsResponse))
          as ListPlaylistsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListPlaylistsResponse create() => ListPlaylistsResponse._();
  @$core.override
  ListPlaylistsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListPlaylistsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListPlaylistsResponse>(create);
  static ListPlaylistsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Playlist> get playlists => $_getList(0);
}

class AddPlaylistEntryRequest extends $pb.GeneratedMessage {
  factory AddPlaylistEntryRequest({
    $fixnum.Int64? playlistId,
    $fixnum.Int64? mediaId,
  }) {
    final result = create();
    if (playlistId != null) result.playlistId = playlistId;
    if (mediaId != null) result.mediaId = mediaId;
    return result;
  }

  AddPlaylistEntryRequest._();

  factory AddPlaylistEntryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddPlaylistEntryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddPlaylistEntryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'playlistId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'mediaId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddPlaylistEntryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddPlaylistEntryRequest copyWith(
          void Function(AddPlaylistEntryRequest) updates) =>
      super.copyWith((message) => updates(message as AddPlaylistEntryRequest))
          as AddPlaylistEntryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddPlaylistEntryRequest create() => AddPlaylistEntryRequest._();
  @$core.override
  AddPlaylistEntryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddPlaylistEntryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddPlaylistEntryRequest>(create);
  static AddPlaylistEntryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get playlistId => $_getI64(0);
  @$pb.TagNumber(1)
  set playlistId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlaylistId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlaylistId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get mediaId => $_getI64(1);
  @$pb.TagNumber(2)
  set mediaId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaId() => $_clearField(2);
}

class GetPlaylistRequest extends $pb.GeneratedMessage {
  factory GetPlaylistRequest({
    $fixnum.Int64? playlistId,
  }) {
    final result = create();
    if (playlistId != null) result.playlistId = playlistId;
    return result;
  }

  GetPlaylistRequest._();

  factory GetPlaylistRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPlaylistRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPlaylistRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'playlistId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPlaylistRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPlaylistRequest copyWith(void Function(GetPlaylistRequest) updates) =>
      super.copyWith((message) => updates(message as GetPlaylistRequest))
          as GetPlaylistRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPlaylistRequest create() => GetPlaylistRequest._();
  @$core.override
  GetPlaylistRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPlaylistRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPlaylistRequest>(create);
  static GetPlaylistRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get playlistId => $_getI64(0);
  @$pb.TagNumber(1)
  set playlistId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlaylistId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlaylistId() => $_clearField(1);
}

class PlayerState extends $pb.GeneratedMessage {
  factory PlayerState({
    $core.String? status,
    $core.String? mediaPath,
    $fixnum.Int64? positionMs,
    $fixnum.Int64? durationMs,
    $fixnum.Int64? playlistId,
  }) {
    final result = create();
    if (status != null) result.status = status;
    if (mediaPath != null) result.mediaPath = mediaPath;
    if (positionMs != null) result.positionMs = positionMs;
    if (durationMs != null) result.durationMs = durationMs;
    if (playlistId != null) result.playlistId = playlistId;
    return result;
  }

  PlayerState._();

  factory PlayerState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlayerState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayerState',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'status')
    ..aOS(2, _omitFieldNames ? '' : 'mediaPath')
    ..aInt64(3, _omitFieldNames ? '' : 'positionMs')
    ..aInt64(4, _omitFieldNames ? '' : 'durationMs')
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'playlistId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayerState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayerState copyWith(void Function(PlayerState) updates) =>
      super.copyWith((message) => updates(message as PlayerState))
          as PlayerState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlayerState create() => PlayerState._();
  @$core.override
  PlayerState createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlayerState getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlayerState>(create);
  static PlayerState? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get status => $_getSZ(0);
  @$pb.TagNumber(1)
  set status($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mediaPath => $_getSZ(1);
  @$pb.TagNumber(2)
  set mediaPath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaPath() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get positionMs => $_getI64(2);
  @$pb.TagNumber(3)
  set positionMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPositionMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearPositionMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get durationMs => $_getI64(3);
  @$pb.TagNumber(4)
  set durationMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDurationMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearDurationMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get playlistId => $_getI64(4);
  @$pb.TagNumber(5)
  set playlistId($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPlaylistId() => $_has(4);
  @$pb.TagNumber(5)
  void clearPlaylistId() => $_clearField(5);
}

class PlayerEvent extends $pb.GeneratedMessage {
  factory PlayerEvent({
    $core.String? event,
    PlayerState? state,
    $core.String? message,
  }) {
    final result = create();
    if (event != null) result.event = event;
    if (state != null) result.state = state;
    if (message != null) result.message = message;
    return result;
  }

  PlayerEvent._();

  factory PlayerEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlayerEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayerEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'event')
    ..aOM<PlayerState>(2, _omitFieldNames ? '' : 'state',
        subBuilder: PlayerState.create)
    ..aOS(3, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayerEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayerEvent copyWith(void Function(PlayerEvent) updates) =>
      super.copyWith((message) => updates(message as PlayerEvent))
          as PlayerEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlayerEvent create() => PlayerEvent._();
  @$core.override
  PlayerEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlayerEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlayerEvent>(create);
  static PlayerEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get event => $_getSZ(0);
  @$pb.TagNumber(1)
  set event($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEvent() => $_has(0);
  @$pb.TagNumber(1)
  void clearEvent() => $_clearField(1);

  @$pb.TagNumber(2)
  PlayerState get state => $_getN(1);
  @$pb.TagNumber(2)
  set state(PlayerState value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasState() => $_has(1);
  @$pb.TagNumber(2)
  void clearState() => $_clearField(2);
  @$pb.TagNumber(2)
  PlayerState ensureState() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get message => $_getSZ(2);
  @$pb.TagNumber(3)
  set message($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessage() => $_clearField(3);
}

class AudioEvent extends $pb.GeneratedMessage {
  factory AudioEvent({
    $core.String? event,
    $core.String? message,
  }) {
    final result = create();
    if (event != null) result.event = event;
    if (message != null) result.message = message;
    return result;
  }

  AudioEvent._();

  factory AudioEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AudioEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AudioEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'event')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AudioEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AudioEvent copyWith(void Function(AudioEvent) updates) =>
      super.copyWith((message) => updates(message as AudioEvent)) as AudioEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AudioEvent create() => AudioEvent._();
  @$core.override
  AudioEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AudioEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AudioEvent>(create);
  static AudioEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get event => $_getSZ(0);
  @$pb.TagNumber(1)
  set event($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEvent() => $_has(0);
  @$pb.TagNumber(1)
  void clearEvent() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class Configuration extends $pb.GeneratedMessage {
  factory Configuration({
    $core.String? serverAddress,
    $core.String? databasePath,
    $core.Iterable<$core.String>? mediaFolders,
    $core.Iterable<$core.String>? supportedFormats,
    $core.bool? rescanOnStart,
    $core.String? resumeMode,
    $core.String? audioBackend,
    $core.String? audioDevice,
    $core.int? sampleRate,
    $core.int? channels,
    $core.String? navigationInterrupt,
    $core.String? logDirectory,
    $core.String? logLevel,
  }) {
    final result = create();
    if (serverAddress != null) result.serverAddress = serverAddress;
    if (databasePath != null) result.databasePath = databasePath;
    if (mediaFolders != null) result.mediaFolders.addAll(mediaFolders);
    if (supportedFormats != null)
      result.supportedFormats.addAll(supportedFormats);
    if (rescanOnStart != null) result.rescanOnStart = rescanOnStart;
    if (resumeMode != null) result.resumeMode = resumeMode;
    if (audioBackend != null) result.audioBackend = audioBackend;
    if (audioDevice != null) result.audioDevice = audioDevice;
    if (sampleRate != null) result.sampleRate = sampleRate;
    if (channels != null) result.channels = channels;
    if (navigationInterrupt != null)
      result.navigationInterrupt = navigationInterrupt;
    if (logDirectory != null) result.logDirectory = logDirectory;
    if (logLevel != null) result.logLevel = logLevel;
    return result;
  }

  Configuration._();

  factory Configuration.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Configuration.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Configuration',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'serverAddress')
    ..aOS(2, _omitFieldNames ? '' : 'databasePath')
    ..pPS(3, _omitFieldNames ? '' : 'mediaFolders')
    ..pPS(4, _omitFieldNames ? '' : 'supportedFormats')
    ..aOB(5, _omitFieldNames ? '' : 'rescanOnStart')
    ..aOS(6, _omitFieldNames ? '' : 'resumeMode')
    ..aOS(7, _omitFieldNames ? '' : 'audioBackend')
    ..aOS(8, _omitFieldNames ? '' : 'audioDevice')
    ..aI(9, _omitFieldNames ? '' : 'sampleRate', fieldType: $pb.PbFieldType.OU3)
    ..aI(10, _omitFieldNames ? '' : 'channels', fieldType: $pb.PbFieldType.OU3)
    ..aOS(11, _omitFieldNames ? '' : 'navigationInterrupt')
    ..aOS(12, _omitFieldNames ? '' : 'logDirectory')
    ..aOS(13, _omitFieldNames ? '' : 'logLevel')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Configuration clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Configuration copyWith(void Function(Configuration) updates) =>
      super.copyWith((message) => updates(message as Configuration))
          as Configuration;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Configuration create() => Configuration._();
  @$core.override
  Configuration createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Configuration getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Configuration>(create);
  static Configuration? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get serverAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set serverAddress($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasServerAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearServerAddress() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get databasePath => $_getSZ(1);
  @$pb.TagNumber(2)
  set databasePath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDatabasePath() => $_has(1);
  @$pb.TagNumber(2)
  void clearDatabasePath() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get mediaFolders => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get supportedFormats => $_getList(3);

  @$pb.TagNumber(5)
  $core.bool get rescanOnStart => $_getBF(4);
  @$pb.TagNumber(5)
  set rescanOnStart($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRescanOnStart() => $_has(4);
  @$pb.TagNumber(5)
  void clearRescanOnStart() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get resumeMode => $_getSZ(5);
  @$pb.TagNumber(6)
  set resumeMode($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasResumeMode() => $_has(5);
  @$pb.TagNumber(6)
  void clearResumeMode() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get audioBackend => $_getSZ(6);
  @$pb.TagNumber(7)
  set audioBackend($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAudioBackend() => $_has(6);
  @$pb.TagNumber(7)
  void clearAudioBackend() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get audioDevice => $_getSZ(7);
  @$pb.TagNumber(8)
  set audioDevice($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAudioDevice() => $_has(7);
  @$pb.TagNumber(8)
  void clearAudioDevice() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get sampleRate => $_getIZ(8);
  @$pb.TagNumber(9)
  set sampleRate($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSampleRate() => $_has(8);
  @$pb.TagNumber(9)
  void clearSampleRate() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get channels => $_getIZ(9);
  @$pb.TagNumber(10)
  set channels($core.int value) => $_setUnsignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasChannels() => $_has(9);
  @$pb.TagNumber(10)
  void clearChannels() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get navigationInterrupt => $_getSZ(10);
  @$pb.TagNumber(11)
  set navigationInterrupt($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasNavigationInterrupt() => $_has(10);
  @$pb.TagNumber(11)
  void clearNavigationInterrupt() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get logDirectory => $_getSZ(11);
  @$pb.TagNumber(12)
  set logDirectory($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasLogDirectory() => $_has(11);
  @$pb.TagNumber(12)
  void clearLogDirectory() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get logLevel => $_getSZ(12);
  @$pb.TagNumber(13)
  set logLevel($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasLogLevel() => $_has(12);
  @$pb.TagNumber(13)
  void clearLogLevel() => $_clearField(13);
}

class UpdateConfigurationRequest extends $pb.GeneratedMessage {
  factory UpdateConfigurationRequest({
    Configuration? configuration,
  }) {
    final result = create();
    if (configuration != null) result.configuration = configuration;
    return result;
  }

  UpdateConfigurationRequest._();

  factory UpdateConfigurationRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateConfigurationRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateConfigurationRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOM<Configuration>(1, _omitFieldNames ? '' : 'configuration',
        subBuilder: Configuration.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateConfigurationRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateConfigurationRequest copyWith(
          void Function(UpdateConfigurationRequest) updates) =>
      super.copyWith(
              (message) => updates(message as UpdateConfigurationRequest))
          as UpdateConfigurationRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateConfigurationRequest create() => UpdateConfigurationRequest._();
  @$core.override
  UpdateConfigurationRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateConfigurationRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateConfigurationRequest>(create);
  static UpdateConfigurationRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Configuration get configuration => $_getN(0);
  @$pb.TagNumber(1)
  set configuration(Configuration value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasConfiguration() => $_has(0);
  @$pb.TagNumber(1)
  void clearConfiguration() => $_clearField(1);
  @$pb.TagNumber(1)
  Configuration ensureConfiguration() => $_ensure(0);
}

class ConfigurationResponse extends $pb.GeneratedMessage {
  factory ConfigurationResponse({
    $core.bool? success,
    $core.String? message,
    Configuration? configuration,
    $core.bool? restartRequired,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (message != null) result.message = message;
    if (configuration != null) result.configuration = configuration;
    if (restartRequired != null) result.restartRequired = restartRequired;
    return result;
  }

  ConfigurationResponse._();

  factory ConfigurationResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConfigurationResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConfigurationResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..aOM<Configuration>(3, _omitFieldNames ? '' : 'configuration',
        subBuilder: Configuration.create)
    ..aOB(4, _omitFieldNames ? '' : 'restartRequired')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfigurationResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfigurationResponse copyWith(
          void Function(ConfigurationResponse) updates) =>
      super.copyWith((message) => updates(message as ConfigurationResponse))
          as ConfigurationResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConfigurationResponse create() => ConfigurationResponse._();
  @$core.override
  ConfigurationResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConfigurationResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConfigurationResponse>(create);
  static ConfigurationResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);

  @$pb.TagNumber(3)
  Configuration get configuration => $_getN(2);
  @$pb.TagNumber(3)
  set configuration(Configuration value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasConfiguration() => $_has(2);
  @$pb.TagNumber(3)
  void clearConfiguration() => $_clearField(3);
  @$pb.TagNumber(3)
  Configuration ensureConfiguration() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.bool get restartRequired => $_getBF(3);
  @$pb.TagNumber(4)
  set restartRequired($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRestartRequired() => $_has(3);
  @$pb.TagNumber(4)
  void clearRestartRequired() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
