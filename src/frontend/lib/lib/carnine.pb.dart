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

import 'carnine.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'carnine.pbenum.dart';

class UiState extends $pb.GeneratedMessage {
  factory UiState({
    $core.String? lastPage,
  }) {
    final result = create();
    if (lastPage != null) result.lastPage = lastPage;
    return result;
  }

  UiState._();

  factory UiState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UiState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UiState',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'lastPage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UiState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UiState copyWith(void Function(UiState) updates) =>
      super.copyWith((message) => updates(message as UiState)) as UiState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UiState create() => UiState._();
  @$core.override
  UiState createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UiState getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UiState>(create);
  static UiState? _defaultInstance;

  /// Dashboard page shown last, by its name (e.g. "maps"); empty when none
  /// was saved yet.
  @$pb.TagNumber(1)
  $core.String get lastPage => $_getSZ(0);
  @$pb.TagNumber(1)
  set lastPage($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLastPage() => $_has(0);
  @$pb.TagNumber(1)
  void clearLastPage() => $_clearField(1);
}

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

class ImportMusicVolumeRequest extends $pb.GeneratedMessage {
  factory ImportMusicVolumeRequest({
    $core.String? sourcePath,
  }) {
    final result = create();
    if (sourcePath != null) result.sourcePath = sourcePath;
    return result;
  }

  ImportMusicVolumeRequest._();

  factory ImportMusicVolumeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ImportMusicVolumeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImportMusicVolumeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sourcePath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportMusicVolumeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportMusicVolumeRequest copyWith(
          void Function(ImportMusicVolumeRequest) updates) =>
      super.copyWith((message) => updates(message as ImportMusicVolumeRequest))
          as ImportMusicVolumeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImportMusicVolumeRequest create() => ImportMusicVolumeRequest._();
  @$core.override
  ImportMusicVolumeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ImportMusicVolumeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImportMusicVolumeRequest>(create);
  static ImportMusicVolumeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sourcePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set sourcePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSourcePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearSourcePath() => $_clearField(1);
}

class LibraryEvent extends $pb.GeneratedMessage {
  factory LibraryEvent({
    LibraryEventType? event,
    $fixnum.Int64? scanId,
    $fixnum.Int64? processed,
    $fixnum.Int64? imported,
    $core.String? path,
    $core.String? message,
    $core.String? sourceLabel,
    $core.String? sourcePath,
    $fixnum.Int64? matchingFiles,
    $fixnum.Int64? playlistId,
    $core.String? playlistName,
  }) {
    final result = create();
    if (event != null) result.event = event;
    if (scanId != null) result.scanId = scanId;
    if (processed != null) result.processed = processed;
    if (imported != null) result.imported = imported;
    if (path != null) result.path = path;
    if (message != null) result.message = message;
    if (sourceLabel != null) result.sourceLabel = sourceLabel;
    if (sourcePath != null) result.sourcePath = sourcePath;
    if (matchingFiles != null) result.matchingFiles = matchingFiles;
    if (playlistId != null) result.playlistId = playlistId;
    if (playlistName != null) result.playlistName = playlistName;
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
    ..aE<LibraryEventType>(1, _omitFieldNames ? '' : 'event',
        enumValues: LibraryEventType.values)
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
    ..aOS(7, _omitFieldNames ? '' : 'sourceLabel')
    ..aOS(8, _omitFieldNames ? '' : 'sourcePath')
    ..a<$fixnum.Int64>(
        9, _omitFieldNames ? '' : 'matchingFiles', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        10, _omitFieldNames ? '' : 'playlistId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(11, _omitFieldNames ? '' : 'playlistName')
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
  LibraryEventType get event => $_getN(0);
  @$pb.TagNumber(1)
  set event(LibraryEventType value) => $_setField(1, value);
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

  @$pb.TagNumber(7)
  $core.String get sourceLabel => $_getSZ(6);
  @$pb.TagNumber(7)
  set sourceLabel($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSourceLabel() => $_has(6);
  @$pb.TagNumber(7)
  void clearSourceLabel() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get sourcePath => $_getSZ(7);
  @$pb.TagNumber(8)
  set sourcePath($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSourcePath() => $_has(7);
  @$pb.TagNumber(8)
  void clearSourcePath() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get matchingFiles => $_getI64(8);
  @$pb.TagNumber(9)
  set matchingFiles($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMatchingFiles() => $_has(8);
  @$pb.TagNumber(9)
  void clearMatchingFiles() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get playlistId => $_getI64(9);
  @$pb.TagNumber(10)
  set playlistId($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasPlaylistId() => $_has(9);
  @$pb.TagNumber(10)
  void clearPlaylistId() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get playlistName => $_getSZ(10);
  @$pb.TagNumber(11)
  set playlistName($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasPlaylistName() => $_has(10);
  @$pb.TagNumber(11)
  void clearPlaylistName() => $_clearField(11);
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
    $core.bool? hasCoverArt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (sourceId != null) result.sourceId = sourceId;
    if (path != null) result.path = path;
    if (title != null) result.title = title;
    if (artist != null) result.artist = artist;
    if (durationMs != null) result.durationMs = durationMs;
    if (status != null) result.status = status;
    if (hasCoverArt != null) result.hasCoverArt = hasCoverArt;
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
    ..aOB(8, _omitFieldNames ? '' : 'hasCoverArt')
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

  @$pb.TagNumber(8)
  $core.bool get hasCoverArt => $_getBF(7);
  @$pb.TagNumber(8)
  set hasCoverArt($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasHasCoverArt() => $_has(7);
  @$pb.TagNumber(8)
  void clearHasCoverArt() => $_clearField(8);
}

class Playlist extends $pb.GeneratedMessage {
  factory Playlist({
    $fixnum.Int64? id,
    $core.String? name,
    $core.Iterable<PlaylistEntry>? entries,
    $core.bool? hasCoverArt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (entries != null) result.entries.addAll(entries);
    if (hasCoverArt != null) result.hasCoverArt = hasCoverArt;
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
    ..aOB(4, _omitFieldNames ? '' : 'hasCoverArt')
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

  @$pb.TagNumber(4)
  $core.bool get hasCoverArt => $_getBF(3);
  @$pb.TagNumber(4)
  set hasCoverArt($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHasCoverArt() => $_has(3);
  @$pb.TagNumber(4)
  void clearHasCoverArt() => $_clearField(4);
}

enum GetCoverArtRequest_Target { mediaId, playlistId, notSet }

class GetCoverArtRequest extends $pb.GeneratedMessage {
  factory GetCoverArtRequest({
    $fixnum.Int64? mediaId,
    $fixnum.Int64? playlistId,
  }) {
    final result = create();
    if (mediaId != null) result.mediaId = mediaId;
    if (playlistId != null) result.playlistId = playlistId;
    return result;
  }

  GetCoverArtRequest._();

  factory GetCoverArtRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetCoverArtRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, GetCoverArtRequest_Target>
      _GetCoverArtRequest_TargetByTag = {
    1: GetCoverArtRequest_Target.mediaId,
    2: GetCoverArtRequest_Target.playlistId,
    0: GetCoverArtRequest_Target.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetCoverArtRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'mediaId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'playlistId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCoverArtRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCoverArtRequest copyWith(void Function(GetCoverArtRequest) updates) =>
      super.copyWith((message) => updates(message as GetCoverArtRequest))
          as GetCoverArtRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetCoverArtRequest create() => GetCoverArtRequest._();
  @$core.override
  GetCoverArtRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetCoverArtRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetCoverArtRequest>(create);
  static GetCoverArtRequest? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  GetCoverArtRequest_Target whichTarget() =>
      _GetCoverArtRequest_TargetByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearTarget() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get mediaId => $_getI64(0);
  @$pb.TagNumber(1)
  set mediaId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMediaId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMediaId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get playlistId => $_getI64(1);
  @$pb.TagNumber(2)
  set playlistId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlaylistId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlaylistId() => $_clearField(2);
}

class GetCoverArtResponse extends $pb.GeneratedMessage {
  factory GetCoverArtResponse({
    $core.List<$core.int>? data,
    $core.String? mimeType,
  }) {
    final result = create();
    if (data != null) result.data = data;
    if (mimeType != null) result.mimeType = mimeType;
    return result;
  }

  GetCoverArtResponse._();

  factory GetCoverArtResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetCoverArtResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetCoverArtResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'mimeType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCoverArtResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCoverArtResponse copyWith(void Function(GetCoverArtResponse) updates) =>
      super.copyWith((message) => updates(message as GetCoverArtResponse))
          as GetCoverArtResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetCoverArtResponse create() => GetCoverArtResponse._();
  @$core.override
  GetCoverArtResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetCoverArtResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetCoverArtResponse>(create);
  static GetCoverArtResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mimeType => $_getSZ(1);
  @$pb.TagNumber(2)
  set mimeType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMimeType() => $_has(1);
  @$pb.TagNumber(2)
  void clearMimeType() => $_clearField(2);
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

class PlayQueueEntryRequest extends $pb.GeneratedMessage {
  factory PlayQueueEntryRequest({
    $core.int? index,
  }) {
    final result = create();
    if (index != null) result.index = index;
    return result;
  }

  PlayQueueEntryRequest._();

  factory PlayQueueEntryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlayQueueEntryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayQueueEntryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'index', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayQueueEntryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayQueueEntryRequest copyWith(
          void Function(PlayQueueEntryRequest) updates) =>
      super.copyWith((message) => updates(message as PlayQueueEntryRequest))
          as PlayQueueEntryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlayQueueEntryRequest create() => PlayQueueEntryRequest._();
  @$core.override
  PlayQueueEntryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlayQueueEntryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlayQueueEntryRequest>(create);
  static PlayQueueEntryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => $_clearField(1);
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
    RepeatMode? repeatMode,
    $core.bool? shuffleEnabled,
  }) {
    final result = create();
    if (status != null) result.status = status;
    if (mediaPath != null) result.mediaPath = mediaPath;
    if (positionMs != null) result.positionMs = positionMs;
    if (durationMs != null) result.durationMs = durationMs;
    if (playlistId != null) result.playlistId = playlistId;
    if (repeatMode != null) result.repeatMode = repeatMode;
    if (shuffleEnabled != null) result.shuffleEnabled = shuffleEnabled;
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
    ..aE<RepeatMode>(6, _omitFieldNames ? '' : 'repeatMode',
        enumValues: RepeatMode.values)
    ..aOB(7, _omitFieldNames ? '' : 'shuffleEnabled')
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

  @$pb.TagNumber(6)
  RepeatMode get repeatMode => $_getN(5);
  @$pb.TagNumber(6)
  set repeatMode(RepeatMode value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasRepeatMode() => $_has(5);
  @$pb.TagNumber(6)
  void clearRepeatMode() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get shuffleEnabled => $_getBF(6);
  @$pb.TagNumber(7)
  set shuffleEnabled($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasShuffleEnabled() => $_has(6);
  @$pb.TagNumber(7)
  void clearShuffleEnabled() => $_clearField(7);
}

class PlayerEvent extends $pb.GeneratedMessage {
  factory PlayerEvent({
    PlayerEventType? event,
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
    ..aE<PlayerEventType>(1, _omitFieldNames ? '' : 'event',
        enumValues: PlayerEventType.values)
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
  PlayerEventType get event => $_getN(0);
  @$pb.TagNumber(1)
  set event(PlayerEventType value) => $_setField(1, value);
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

class SetRepeatModeRequest extends $pb.GeneratedMessage {
  factory SetRepeatModeRequest({
    RepeatMode? mode,
  }) {
    final result = create();
    if (mode != null) result.mode = mode;
    return result;
  }

  SetRepeatModeRequest._();

  factory SetRepeatModeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetRepeatModeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetRepeatModeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aE<RepeatMode>(1, _omitFieldNames ? '' : 'mode',
        enumValues: RepeatMode.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetRepeatModeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetRepeatModeRequest copyWith(void Function(SetRepeatModeRequest) updates) =>
      super.copyWith((message) => updates(message as SetRepeatModeRequest))
          as SetRepeatModeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetRepeatModeRequest create() => SetRepeatModeRequest._();
  @$core.override
  SetRepeatModeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetRepeatModeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetRepeatModeRequest>(create);
  static SetRepeatModeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  RepeatMode get mode => $_getN(0);
  @$pb.TagNumber(1)
  set mode(RepeatMode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMode() => $_has(0);
  @$pb.TagNumber(1)
  void clearMode() => $_clearField(1);
}

class SetShuffleModeRequest extends $pb.GeneratedMessage {
  factory SetShuffleModeRequest({
    $core.bool? enabled,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    return result;
  }

  SetShuffleModeRequest._();

  factory SetShuffleModeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetShuffleModeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetShuffleModeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetShuffleModeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetShuffleModeRequest copyWith(
          void Function(SetShuffleModeRequest) updates) =>
      super.copyWith((message) => updates(message as SetShuffleModeRequest))
          as SetShuffleModeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetShuffleModeRequest create() => SetShuffleModeRequest._();
  @$core.override
  SetShuffleModeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetShuffleModeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetShuffleModeRequest>(create);
  static SetShuffleModeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);
}

class AudioEvent extends $pb.GeneratedMessage {
  factory AudioEvent({
    AudioEventType? event,
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
    ..aE<AudioEventType>(1, _omitFieldNames ? '' : 'event',
        enumValues: AudioEventType.values)
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
  AudioEventType get event => $_getN(0);
  @$pb.TagNumber(1)
  set event(AudioEventType value) => $_setField(1, value);
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

class SetVolumeRequest extends $pb.GeneratedMessage {
  factory SetVolumeRequest({
    $core.int? percent,
  }) {
    final result = create();
    if (percent != null) result.percent = percent;
    return result;
  }

  SetVolumeRequest._();

  factory SetVolumeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetVolumeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetVolumeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'percent', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetVolumeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetVolumeRequest copyWith(void Function(SetVolumeRequest) updates) =>
      super.copyWith((message) => updates(message as SetVolumeRequest))
          as SetVolumeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetVolumeRequest create() => SetVolumeRequest._();
  @$core.override
  SetVolumeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetVolumeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetVolumeRequest>(create);
  static SetVolumeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get percent => $_getIZ(0);
  @$pb.TagNumber(1)
  set percent($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPercent() => $_has(0);
  @$pb.TagNumber(1)
  void clearPercent() => $_clearField(1);
}

class VolumeResponse extends $pb.GeneratedMessage {
  factory VolumeResponse({
    $core.int? percent,
  }) {
    final result = create();
    if (percent != null) result.percent = percent;
    return result;
  }

  VolumeResponse._();

  factory VolumeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory VolumeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VolumeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'percent', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VolumeResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VolumeResponse copyWith(void Function(VolumeResponse) updates) =>
      super.copyWith((message) => updates(message as VolumeResponse))
          as VolumeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static VolumeResponse create() => VolumeResponse._();
  @$core.override
  VolumeResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static VolumeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VolumeResponse>(create);
  static VolumeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get percent => $_getIZ(0);
  @$pb.TagNumber(1)
  set percent($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPercent() => $_has(0);
  @$pb.TagNumber(1)
  void clearPercent() => $_clearField(1);
}

class Configuration extends $pb.GeneratedMessage {
  factory Configuration({
    $core.String? socketPath,
    $core.String? databasePath,
    $core.Iterable<$core.String>? mediaFolders,
    $core.Iterable<$core.String>? supportedFormats,
    $core.bool? rescanOnStart,
    $core.String? resumeMode,
    $core.String? navigationInterrupt,
    $core.String? logDirectory,
    $core.String? logLevel,
    $core.String? coverCacheDir,
    $core.String? tcpAddress,
    $fixnum.Int64? metricsIntervalSeconds,
    $fixnum.Int64? diskMetricsIntervalSeconds,
    $core.Iterable<$core.String>? diskPaths,
    $core.String? socketMode,
  }) {
    final result = create();
    if (socketPath != null) result.socketPath = socketPath;
    if (databasePath != null) result.databasePath = databasePath;
    if (mediaFolders != null) result.mediaFolders.addAll(mediaFolders);
    if (supportedFormats != null)
      result.supportedFormats.addAll(supportedFormats);
    if (rescanOnStart != null) result.rescanOnStart = rescanOnStart;
    if (resumeMode != null) result.resumeMode = resumeMode;
    if (navigationInterrupt != null)
      result.navigationInterrupt = navigationInterrupt;
    if (logDirectory != null) result.logDirectory = logDirectory;
    if (logLevel != null) result.logLevel = logLevel;
    if (coverCacheDir != null) result.coverCacheDir = coverCacheDir;
    if (tcpAddress != null) result.tcpAddress = tcpAddress;
    if (metricsIntervalSeconds != null)
      result.metricsIntervalSeconds = metricsIntervalSeconds;
    if (diskMetricsIntervalSeconds != null)
      result.diskMetricsIntervalSeconds = diskMetricsIntervalSeconds;
    if (diskPaths != null) result.diskPaths.addAll(diskPaths);
    if (socketMode != null) result.socketMode = socketMode;
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
    ..aOS(1, _omitFieldNames ? '' : 'socketPath')
    ..aOS(2, _omitFieldNames ? '' : 'databasePath')
    ..pPS(3, _omitFieldNames ? '' : 'mediaFolders')
    ..pPS(4, _omitFieldNames ? '' : 'supportedFormats')
    ..aOB(5, _omitFieldNames ? '' : 'rescanOnStart')
    ..aOS(6, _omitFieldNames ? '' : 'resumeMode')
    ..aOS(11, _omitFieldNames ? '' : 'navigationInterrupt')
    ..aOS(12, _omitFieldNames ? '' : 'logDirectory')
    ..aOS(13, _omitFieldNames ? '' : 'logLevel')
    ..aOS(14, _omitFieldNames ? '' : 'coverCacheDir')
    ..aOS(15, _omitFieldNames ? '' : 'tcpAddress')
    ..a<$fixnum.Int64>(16, _omitFieldNames ? '' : 'metricsIntervalSeconds',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(17, _omitFieldNames ? '' : 'diskMetricsIntervalSeconds',
        $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPS(18, _omitFieldNames ? '' : 'diskPaths')
    ..aOS(19, _omitFieldNames ? '' : 'socketMode')
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
  $core.String get socketPath => $_getSZ(0);
  @$pb.TagNumber(1)
  set socketPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSocketPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearSocketPath() => $_clearField(1);

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

  @$pb.TagNumber(11)
  $core.String get navigationInterrupt => $_getSZ(6);
  @$pb.TagNumber(11)
  set navigationInterrupt($core.String value) => $_setString(6, value);
  @$pb.TagNumber(11)
  $core.bool hasNavigationInterrupt() => $_has(6);
  @$pb.TagNumber(11)
  void clearNavigationInterrupt() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get logDirectory => $_getSZ(7);
  @$pb.TagNumber(12)
  set logDirectory($core.String value) => $_setString(7, value);
  @$pb.TagNumber(12)
  $core.bool hasLogDirectory() => $_has(7);
  @$pb.TagNumber(12)
  void clearLogDirectory() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get logLevel => $_getSZ(8);
  @$pb.TagNumber(13)
  set logLevel($core.String value) => $_setString(8, value);
  @$pb.TagNumber(13)
  $core.bool hasLogLevel() => $_has(8);
  @$pb.TagNumber(13)
  void clearLogLevel() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get coverCacheDir => $_getSZ(9);
  @$pb.TagNumber(14)
  set coverCacheDir($core.String value) => $_setString(9, value);
  @$pb.TagNumber(14)
  $core.bool hasCoverCacheDir() => $_has(9);
  @$pb.TagNumber(14)
  void clearCoverCacheDir() => $_clearField(14);

  /// Optional TCP loopback fallback (ADR-002); empty means unset. Must stay
  /// unset in production - see docs/07-deployment.md §7.4.
  @$pb.TagNumber(15)
  $core.String get tcpAddress => $_getSZ(10);
  @$pb.TagNumber(15)
  set tcpAddress($core.String value) => $_setString(10, value);
  @$pb.TagNumber(15)
  $core.bool hasTcpAddress() => $_has(10);
  @$pb.TagNumber(15)
  void clearTcpAddress() => $_clearField(15);

  /// Health sampling, see SystemService.GetSystemMetrics.
  @$pb.TagNumber(16)
  $fixnum.Int64 get metricsIntervalSeconds => $_getI64(11);
  @$pb.TagNumber(16)
  set metricsIntervalSeconds($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(16)
  $core.bool hasMetricsIntervalSeconds() => $_has(11);
  @$pb.TagNumber(16)
  void clearMetricsIntervalSeconds() => $_clearField(16);

  @$pb.TagNumber(17)
  $fixnum.Int64 get diskMetricsIntervalSeconds => $_getI64(12);
  @$pb.TagNumber(17)
  set diskMetricsIntervalSeconds($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(17)
  $core.bool hasDiskMetricsIntervalSeconds() => $_has(12);
  @$pb.TagNumber(17)
  void clearDiskMetricsIntervalSeconds() => $_clearField(17);

  /// Empty means the default: root filesystem plus every media folder.
  @$pb.TagNumber(18)
  $pb.PbList<$core.String> get diskPaths => $_getList(13);

  /// Octal socket permissions such as "0660"; empty means the production
  /// default 0600. See docs/07-deployment.md §7.4.
  @$pb.TagNumber(19)
  $core.String get socketMode => $_getSZ(14);
  @$pb.TagNumber(19)
  set socketMode($core.String value) => $_setString(14, value);
  @$pb.TagNumber(19)
  $core.bool hasSocketMode() => $_has(14);
  @$pb.TagNumber(19)
  void clearSocketMode() => $_clearField(19);
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

class DiskUsage extends $pb.GeneratedMessage {
  factory DiskUsage({
    $core.String? path,
    $core.String? mountPoint,
    $fixnum.Int64? totalBytes,
    $fixnum.Int64? availableBytes,
    $core.double? usedPercent,
  }) {
    final result = create();
    if (path != null) result.path = path;
    if (mountPoint != null) result.mountPoint = mountPoint;
    if (totalBytes != null) result.totalBytes = totalBytes;
    if (availableBytes != null) result.availableBytes = availableBytes;
    if (usedPercent != null) result.usedPercent = usedPercent;
    return result;
  }

  DiskUsage._();

  factory DiskUsage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DiskUsage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DiskUsage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'mountPoint')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'totalBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'availableBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aD(5, _omitFieldNames ? '' : 'usedPercent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiskUsage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiskUsage copyWith(void Function(DiskUsage) updates) =>
      super.copyWith((message) => updates(message as DiskUsage)) as DiskUsage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DiskUsage create() => DiskUsage._();
  @$core.override
  DiskUsage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DiskUsage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DiskUsage>(create);
  static DiskUsage? _defaultInstance;

  /// Path that was probed, as configured in system.disk_paths.
  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  /// Mount point the path resolves to; several configured paths can share one.
  @$pb.TagNumber(2)
  $core.String get mountPoint => $_getSZ(1);
  @$pb.TagNumber(2)
  set mountPoint($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMountPoint() => $_has(1);
  @$pb.TagNumber(2)
  void clearMountPoint() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get totalBytes => $_getI64(2);
  @$pb.TagNumber(3)
  set totalBytes($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalBytes() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalBytes() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get availableBytes => $_getI64(3);
  @$pb.TagNumber(4)
  set availableBytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAvailableBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearAvailableBytes() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get usedPercent => $_getN(4);
  @$pb.TagNumber(5)
  set usedPercent($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUsedPercent() => $_has(4);
  @$pb.TagNumber(5)
  void clearUsedPercent() => $_clearField(5);
}

class SystemMetrics extends $pb.GeneratedMessage {
  factory SystemMetrics({
    $core.double? cpuTemperatureCelsius,
    $core.double? cpuUsagePercent,
    $core.double? loadAverage1m,
    $core.double? loadAverage5m,
    $core.double? loadAverage15m,
    $core.int? cpuCount,
    $fixnum.Int64? uptimeSeconds,
    $fixnum.Int64? sampledAtUnixMs,
    $core.Iterable<DiskUsage>? disks,
    $fixnum.Int64? disksSampledAtUnixMs,
  }) {
    final result = create();
    if (cpuTemperatureCelsius != null)
      result.cpuTemperatureCelsius = cpuTemperatureCelsius;
    if (cpuUsagePercent != null) result.cpuUsagePercent = cpuUsagePercent;
    if (loadAverage1m != null) result.loadAverage1m = loadAverage1m;
    if (loadAverage5m != null) result.loadAverage5m = loadAverage5m;
    if (loadAverage15m != null) result.loadAverage15m = loadAverage15m;
    if (cpuCount != null) result.cpuCount = cpuCount;
    if (uptimeSeconds != null) result.uptimeSeconds = uptimeSeconds;
    if (sampledAtUnixMs != null) result.sampledAtUnixMs = sampledAtUnixMs;
    if (disks != null) result.disks.addAll(disks);
    if (disksSampledAtUnixMs != null)
      result.disksSampledAtUnixMs = disksSampledAtUnixMs;
    return result;
  }

  SystemMetrics._();

  factory SystemMetrics.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SystemMetrics.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SystemMetrics',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'cpuTemperatureCelsius')
    ..aD(2, _omitFieldNames ? '' : 'cpuUsagePercent')
    ..aD(3, _omitFieldNames ? '' : 'loadAverage1m',
        protoName: 'load_average_1m')
    ..aD(4, _omitFieldNames ? '' : 'loadAverage5m',
        protoName: 'load_average_5m')
    ..aD(5, _omitFieldNames ? '' : 'loadAverage15m',
        protoName: 'load_average_15m')
    ..aI(6, _omitFieldNames ? '' : 'cpuCount', fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(
        7, _omitFieldNames ? '' : 'uptimeSeconds', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(8, _omitFieldNames ? '' : 'sampledAtUnixMs')
    ..pPM<DiskUsage>(9, _omitFieldNames ? '' : 'disks',
        subBuilder: DiskUsage.create)
    ..aInt64(10, _omitFieldNames ? '' : 'disksSampledAtUnixMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SystemMetrics clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SystemMetrics copyWith(void Function(SystemMetrics) updates) =>
      super.copyWith((message) => updates(message as SystemMetrics))
          as SystemMetrics;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SystemMetrics create() => SystemMetrics._();
  @$core.override
  SystemMetrics createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SystemMetrics getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SystemMetrics>(create);
  static SystemMetrics? _defaultInstance;

  /// CPU package temperature. Absent when the board exposes no thermal zone.
  @$pb.TagNumber(1)
  $core.double get cpuTemperatureCelsius => $_getN(0);
  @$pb.TagNumber(1)
  set cpuTemperatureCelsius($core.double value) => $_setDouble(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCpuTemperatureCelsius() => $_has(0);
  @$pb.TagNumber(1)
  void clearCpuTemperatureCelsius() => $_clearField(1);

  /// CPU utilisation across all cores between the last two samples, 0..100.
  /// Absent for the very first sample, which has no predecessor to diff.
  @$pb.TagNumber(2)
  $core.double get cpuUsagePercent => $_getN(1);
  @$pb.TagNumber(2)
  set cpuUsagePercent($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCpuUsagePercent() => $_has(1);
  @$pb.TagNumber(2)
  void clearCpuUsagePercent() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get loadAverage1m => $_getN(2);
  @$pb.TagNumber(3)
  set loadAverage1m($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLoadAverage1m() => $_has(2);
  @$pb.TagNumber(3)
  void clearLoadAverage1m() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get loadAverage5m => $_getN(3);
  @$pb.TagNumber(4)
  set loadAverage5m($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLoadAverage5m() => $_has(3);
  @$pb.TagNumber(4)
  void clearLoadAverage5m() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get loadAverage15m => $_getN(4);
  @$pb.TagNumber(5)
  set loadAverage15m($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLoadAverage15m() => $_has(4);
  @$pb.TagNumber(5)
  void clearLoadAverage15m() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get cpuCount => $_getIZ(5);
  @$pb.TagNumber(6)
  set cpuCount($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCpuCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearCpuCount() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get uptimeSeconds => $_getI64(6);
  @$pb.TagNumber(7)
  set uptimeSeconds($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUptimeSeconds() => $_has(6);
  @$pb.TagNumber(7)
  void clearUptimeSeconds() => $_clearField(7);

  /// When the CPU values above were sampled.
  @$pb.TagNumber(8)
  $fixnum.Int64 get sampledAtUnixMs => $_getI64(7);
  @$pb.TagNumber(8)
  set sampledAtUnixMs($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSampledAtUnixMs() => $_has(7);
  @$pb.TagNumber(8)
  void clearSampledAtUnixMs() => $_clearField(8);

  /// Disk usage is sampled on its own, slower cadence
  /// (system.disk_metrics_interval_seconds), so it carries its own timestamp
  /// and repeats unchanged across several CPU samples.
  @$pb.TagNumber(9)
  $pb.PbList<DiskUsage> get disks => $_getList(8);

  @$pb.TagNumber(10)
  $fixnum.Int64 get disksSampledAtUnixMs => $_getI64(9);
  @$pb.TagNumber(10)
  set disksSampledAtUnixMs($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDisksSampledAtUnixMs() => $_has(9);
  @$pb.TagNumber(10)
  void clearDisksSampledAtUnixMs() => $_clearField(10);
}

class LatLon extends $pb.GeneratedMessage {
  factory LatLon({
    $core.double? latitude,
    $core.double? longitude,
  }) {
    final result = create();
    if (latitude != null) result.latitude = latitude;
    if (longitude != null) result.longitude = longitude;
    return result;
  }

  LatLon._();

  factory LatLon.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LatLon.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LatLon',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'latitude')
    ..aD(2, _omitFieldNames ? '' : 'longitude')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LatLon clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LatLon copyWith(void Function(LatLon) updates) =>
      super.copyWith((message) => updates(message as LatLon)) as LatLon;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LatLon create() => LatLon._();
  @$core.override
  LatLon createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LatLon getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LatLon>(create);
  static LatLon? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get latitude => $_getN(0);
  @$pb.TagNumber(1)
  set latitude($core.double value) => $_setDouble(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLatitude() => $_has(0);
  @$pb.TagNumber(1)
  void clearLatitude() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get longitude => $_getN(1);
  @$pb.TagNumber(2)
  set longitude($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLongitude() => $_has(1);
  @$pb.TagNumber(2)
  void clearLongitude() => $_clearField(2);
}

class PositionFix extends $pb.GeneratedMessage {
  factory PositionFix({
    FixState? fixState,
    LatLon? location,
    $core.double? headingDegrees,
    $core.double? speedMps,
    $core.double? accuracyMeters,
    $fixnum.Int64? timestampUtcMs,
    PositionSourceKind? source,
  }) {
    final result = create();
    if (fixState != null) result.fixState = fixState;
    if (location != null) result.location = location;
    if (headingDegrees != null) result.headingDegrees = headingDegrees;
    if (speedMps != null) result.speedMps = speedMps;
    if (accuracyMeters != null) result.accuracyMeters = accuracyMeters;
    if (timestampUtcMs != null) result.timestampUtcMs = timestampUtcMs;
    if (source != null) result.source = source;
    return result;
  }

  PositionFix._();

  factory PositionFix.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PositionFix.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PositionFix',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aE<FixState>(1, _omitFieldNames ? '' : 'fixState',
        enumValues: FixState.values)
    ..aOM<LatLon>(2, _omitFieldNames ? '' : 'location',
        subBuilder: LatLon.create)
    ..aD(3, _omitFieldNames ? '' : 'headingDegrees')
    ..aD(4, _omitFieldNames ? '' : 'speedMps')
    ..aD(5, _omitFieldNames ? '' : 'accuracyMeters')
    ..aInt64(6, _omitFieldNames ? '' : 'timestampUtcMs')
    ..aE<PositionSourceKind>(7, _omitFieldNames ? '' : 'source',
        enumValues: PositionSourceKind.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PositionFix clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PositionFix copyWith(void Function(PositionFix) updates) =>
      super.copyWith((message) => updates(message as PositionFix))
          as PositionFix;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PositionFix create() => PositionFix._();
  @$core.override
  PositionFix createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PositionFix getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PositionFix>(create);
  static PositionFix? _defaultInstance;

  @$pb.TagNumber(1)
  FixState get fixState => $_getN(0);
  @$pb.TagNumber(1)
  set fixState(FixState value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasFixState() => $_has(0);
  @$pb.TagNumber(1)
  void clearFixState() => $_clearField(1);

  @$pb.TagNumber(2)
  LatLon get location => $_getN(1);
  @$pb.TagNumber(2)
  set location(LatLon value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasLocation() => $_has(1);
  @$pb.TagNumber(2)
  void clearLocation() => $_clearField(2);
  @$pb.TagNumber(2)
  LatLon ensureLocation() => $_ensure(1);

  /// Course over ground, 0 = north, clockwise. Raw: the map smooths it and
  /// freezes it at standstill, smoothing here as well would lag behind turns.
  @$pb.TagNumber(3)
  $core.double get headingDegrees => $_getN(2);
  @$pb.TagNumber(3)
  set headingDegrees($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeadingDegrees() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeadingDegrees() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get speedMps => $_getN(3);
  @$pb.TagNumber(4)
  set speedMps($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSpeedMps() => $_has(3);
  @$pb.TagNumber(4)
  void clearSpeedMps() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get accuracyMeters => $_getN(4);
  @$pb.TagNumber(5)
  set accuracyMeters($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAccuracyMeters() => $_has(4);
  @$pb.TagNumber(5)
  void clearAccuracyMeters() => $_clearField(5);

  /// GPS time from the fix, not the Pi's clock (no RTC).
  @$pb.TagNumber(6)
  $fixnum.Int64 get timestampUtcMs => $_getI64(5);
  @$pb.TagNumber(6)
  set timestampUtcMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTimestampUtcMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearTimestampUtcMs() => $_clearField(6);

  @$pb.TagNumber(7)
  PositionSourceKind get source => $_getN(6);
  @$pb.TagNumber(7)
  set source(PositionSourceKind value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSource() => $_has(6);
  @$pb.TagNumber(7)
  void clearSource() => $_clearField(7);
}

class NavigationStatus extends $pb.GeneratedMessage {
  factory NavigationStatus({
    $core.bool? routingAvailable,
    PositionSourceKind? positionSource,
    FixState? fixState,
    $core.String? mapRegion,
  }) {
    final result = create();
    if (routingAvailable != null) result.routingAvailable = routingAvailable;
    if (positionSource != null) result.positionSource = positionSource;
    if (fixState != null) result.fixState = fixState;
    if (mapRegion != null) result.mapRegion = mapRegion;
    return result;
  }

  NavigationStatus._();

  factory NavigationStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NavigationStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NavigationStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'routingAvailable')
    ..aE<PositionSourceKind>(2, _omitFieldNames ? '' : 'positionSource',
        enumValues: PositionSourceKind.values)
    ..aE<FixState>(3, _omitFieldNames ? '' : 'fixState',
        enumValues: FixState.values)
    ..aOS(4, _omitFieldNames ? '' : 'mapRegion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NavigationStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NavigationStatus copyWith(void Function(NavigationStatus) updates) =>
      super.copyWith((message) => updates(message as NavigationStatus))
          as NavigationStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NavigationStatus create() => NavigationStatus._();
  @$core.override
  NavigationStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NavigationStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NavigationStatus>(create);
  static NavigationStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get routingAvailable => $_getBF(0);
  @$pb.TagNumber(1)
  set routingAvailable($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoutingAvailable() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoutingAvailable() => $_clearField(1);

  @$pb.TagNumber(2)
  PositionSourceKind get positionSource => $_getN(1);
  @$pb.TagNumber(2)
  set positionSource(PositionSourceKind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPositionSource() => $_has(1);
  @$pb.TagNumber(2)
  void clearPositionSource() => $_clearField(2);

  @$pb.TagNumber(3)
  FixState get fixState => $_getN(2);
  @$pb.TagNumber(3)
  set fixState(FixState value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasFixState() => $_has(2);
  @$pb.TagNumber(3)
  void clearFixState() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get mapRegion => $_getSZ(3);
  @$pb.TagNumber(4)
  set mapRegion($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMapRegion() => $_has(3);
  @$pb.TagNumber(4)
  void clearMapRegion() => $_clearField(4);
}

class Place extends $pb.GeneratedMessage {
  factory Place({
    $core.String? name,
    LatLon? location,
    $core.int? zoom,
    PlaceType? type,
    $core.String? detail,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (location != null) result.location = location;
    if (zoom != null) result.zoom = zoom;
    if (type != null) result.type = type;
    if (detail != null) result.detail = detail;
    return result;
  }

  Place._();

  factory Place.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Place.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Place',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOM<LatLon>(2, _omitFieldNames ? '' : 'location',
        subBuilder: LatLon.create)
    ..aI(3, _omitFieldNames ? '' : 'zoom', fieldType: $pb.PbFieldType.OU3)
    ..aE<PlaceType>(4, _omitFieldNames ? '' : 'type',
        enumValues: PlaceType.values)
    ..aOS(5, _omitFieldNames ? '' : 'detail')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Place clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Place copyWith(void Function(Place) updates) =>
      super.copyWith((message) => updates(message as Place)) as Place;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Place create() => Place._();
  @$core.override
  Place createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Place getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Place>(create);
  static Place? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  LatLon get location => $_getN(1);
  @$pb.TagNumber(2)
  set location(LatLon value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasLocation() => $_has(1);
  @$pb.TagNumber(2)
  void clearLocation() => $_clearField(2);
  @$pb.TagNumber(2)
  LatLon ensureLocation() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.int get zoom => $_getIZ(2);
  @$pb.TagNumber(3)
  set zoom($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasZoom() => $_has(2);
  @$pb.TagNumber(3)
  void clearZoom() => $_clearField(3);

  @$pb.TagNumber(4)
  PlaceType get type => $_getN(3);
  @$pb.TagNumber(4)
  set type(PlaceType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get detail => $_getSZ(4);
  @$pb.TagNumber(5)
  set detail($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDetail() => $_has(4);
  @$pb.TagNumber(5)
  void clearDetail() => $_clearField(5);
}

class SearchPlacesRequest extends $pb.GeneratedMessage {
  factory SearchPlacesRequest({
    $core.String? query,
    $core.int? limit,
    LatLon? near,
  }) {
    final result = create();
    if (query != null) result.query = query;
    if (limit != null) result.limit = limit;
    if (near != null) result.near = near;
    return result;
  }

  SearchPlacesRequest._();

  factory SearchPlacesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchPlacesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchPlacesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'query')
    ..aI(2, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..aOM<LatLon>(3, _omitFieldNames ? '' : 'near', subBuilder: LatLon.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchPlacesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchPlacesRequest copyWith(void Function(SearchPlacesRequest) updates) =>
      super.copyWith((message) => updates(message as SearchPlacesRequest))
          as SearchPlacesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchPlacesRequest create() => SearchPlacesRequest._();
  @$core.override
  SearchPlacesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SearchPlacesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchPlacesRequest>(create);
  static SearchPlacesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get query => $_getSZ(0);
  @$pb.TagNumber(1)
  set query($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuery() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuery() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get limit => $_getIZ(1);
  @$pb.TagNumber(2)
  set limit($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLimit() => $_has(1);
  @$pb.TagNumber(2)
  void clearLimit() => $_clearField(2);

  @$pb.TagNumber(3)
  LatLon get near => $_getN(2);
  @$pb.TagNumber(3)
  set near(LatLon value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasNear() => $_has(2);
  @$pb.TagNumber(3)
  void clearNear() => $_clearField(3);
  @$pb.TagNumber(3)
  LatLon ensureNear() => $_ensure(2);
}

class SearchPlacesResponse extends $pb.GeneratedMessage {
  factory SearchPlacesResponse({
    $core.Iterable<Place>? places,
  }) {
    final result = create();
    if (places != null) result.places.addAll(places);
    return result;
  }

  SearchPlacesResponse._();

  factory SearchPlacesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchPlacesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchPlacesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..pPM<Place>(1, _omitFieldNames ? '' : 'places', subBuilder: Place.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchPlacesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchPlacesResponse copyWith(void Function(SearchPlacesResponse) updates) =>
      super.copyWith((message) => updates(message as SearchPlacesResponse))
          as SearchPlacesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchPlacesResponse create() => SearchPlacesResponse._();
  @$core.override
  SearchPlacesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SearchPlacesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchPlacesResponse>(create);
  static SearchPlacesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Place> get places => $_getList(0);
}

class ComputeRouteRequest extends $pb.GeneratedMessage {
  factory ComputeRouteRequest({
    LatLon? origin,
    LatLon? destination,
    $core.String? language,
  }) {
    final result = create();
    if (origin != null) result.origin = origin;
    if (destination != null) result.destination = destination;
    if (language != null) result.language = language;
    return result;
  }

  ComputeRouteRequest._();

  factory ComputeRouteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComputeRouteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComputeRouteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOM<LatLon>(1, _omitFieldNames ? '' : 'origin', subBuilder: LatLon.create)
    ..aOM<LatLon>(2, _omitFieldNames ? '' : 'destination',
        subBuilder: LatLon.create)
    ..aOS(4, _omitFieldNames ? '' : 'language')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComputeRouteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComputeRouteRequest copyWith(void Function(ComputeRouteRequest) updates) =>
      super.copyWith((message) => updates(message as ComputeRouteRequest))
          as ComputeRouteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComputeRouteRequest create() => ComputeRouteRequest._();
  @$core.override
  ComputeRouteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComputeRouteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComputeRouteRequest>(create);
  static ComputeRouteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  LatLon get origin => $_getN(0);
  @$pb.TagNumber(1)
  set origin(LatLon value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasOrigin() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrigin() => $_clearField(1);
  @$pb.TagNumber(1)
  LatLon ensureOrigin() => $_ensure(0);

  @$pb.TagNumber(2)
  LatLon get destination => $_getN(1);
  @$pb.TagNumber(2)
  set destination(LatLon value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasDestination() => $_has(1);
  @$pb.TagNumber(2)
  void clearDestination() => $_clearField(2);
  @$pb.TagNumber(2)
  LatLon ensureDestination() => $_ensure(1);

  @$pb.TagNumber(4)
  $core.String get language => $_getSZ(2);
  @$pb.TagNumber(4)
  set language($core.String value) => $_setString(2, value);
  @$pb.TagNumber(4)
  $core.bool hasLanguage() => $_has(2);
  @$pb.TagNumber(4)
  void clearLanguage() => $_clearField(4);
}

class GetReplayRouteRequest extends $pb.GeneratedMessage {
  factory GetReplayRouteRequest({
    $core.String? language,
  }) {
    final result = create();
    if (language != null) result.language = language;
    return result;
  }

  GetReplayRouteRequest._();

  factory GetReplayRouteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetReplayRouteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetReplayRouteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'language')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetReplayRouteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetReplayRouteRequest copyWith(
          void Function(GetReplayRouteRequest) updates) =>
      super.copyWith((message) => updates(message as GetReplayRouteRequest))
          as GetReplayRouteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetReplayRouteRequest create() => GetReplayRouteRequest._();
  @$core.override
  GetReplayRouteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetReplayRouteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetReplayRouteRequest>(create);
  static GetReplayRouteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get language => $_getSZ(0);
  @$pb.TagNumber(1)
  set language($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLanguage() => $_has(0);
  @$pb.TagNumber(1)
  void clearLanguage() => $_clearField(1);
}

class Maneuver extends $pb.GeneratedMessage {
  factory Maneuver({
    $core.String? instruction,
    $core.double? lengthMeters,
    $core.double? timeSeconds,
    $core.int? type,
    $core.int? beginShapeIndex,
    $core.Iterable<$core.String>? streetNames,
  }) {
    final result = create();
    if (instruction != null) result.instruction = instruction;
    if (lengthMeters != null) result.lengthMeters = lengthMeters;
    if (timeSeconds != null) result.timeSeconds = timeSeconds;
    if (type != null) result.type = type;
    if (beginShapeIndex != null) result.beginShapeIndex = beginShapeIndex;
    if (streetNames != null) result.streetNames.addAll(streetNames);
    return result;
  }

  Maneuver._();

  factory Maneuver.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Maneuver.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Maneuver',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'instruction')
    ..aD(2, _omitFieldNames ? '' : 'lengthMeters')
    ..aD(3, _omitFieldNames ? '' : 'timeSeconds')
    ..aI(4, _omitFieldNames ? '' : 'type', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'beginShapeIndex',
        fieldType: $pb.PbFieldType.OU3)
    ..pPS(6, _omitFieldNames ? '' : 'streetNames')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Maneuver clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Maneuver copyWith(void Function(Maneuver) updates) =>
      super.copyWith((message) => updates(message as Maneuver)) as Maneuver;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Maneuver create() => Maneuver._();
  @$core.override
  Maneuver createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Maneuver getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Maneuver>(create);
  static Maneuver? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get instruction => $_getSZ(0);
  @$pb.TagNumber(1)
  set instruction($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInstruction() => $_has(0);
  @$pb.TagNumber(1)
  void clearInstruction() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get lengthMeters => $_getN(1);
  @$pb.TagNumber(2)
  set lengthMeters($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLengthMeters() => $_has(1);
  @$pb.TagNumber(2)
  void clearLengthMeters() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get timeSeconds => $_getN(2);
  @$pb.TagNumber(3)
  set timeSeconds($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimeSeconds() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimeSeconds() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get type => $_getIZ(3);
  @$pb.TagNumber(4)
  set type($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get beginShapeIndex => $_getIZ(4);
  @$pb.TagNumber(5)
  set beginShapeIndex($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBeginShapeIndex() => $_has(4);
  @$pb.TagNumber(5)
  void clearBeginShapeIndex() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get streetNames => $_getList(5);
}

class Route extends $pb.GeneratedMessage {
  factory Route({
    $core.String? routeId,
    $core.Iterable<LatLon>? geometry,
    $core.double? distanceMeters,
    $core.double? durationSeconds,
    $core.Iterable<Maneuver>? maneuvers,
  }) {
    final result = create();
    if (routeId != null) result.routeId = routeId;
    if (geometry != null) result.geometry.addAll(geometry);
    if (distanceMeters != null) result.distanceMeters = distanceMeters;
    if (durationSeconds != null) result.durationSeconds = durationSeconds;
    if (maneuvers != null) result.maneuvers.addAll(maneuvers);
    return result;
  }

  Route._();

  factory Route.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Route.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Route',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'carnine'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'routeId')
    ..pPM<LatLon>(2, _omitFieldNames ? '' : 'geometry',
        subBuilder: LatLon.create)
    ..aD(3, _omitFieldNames ? '' : 'distanceMeters')
    ..aD(4, _omitFieldNames ? '' : 'durationSeconds')
    ..pPM<Maneuver>(5, _omitFieldNames ? '' : 'maneuvers',
        subBuilder: Maneuver.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Route clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Route copyWith(void Function(Route) updates) =>
      super.copyWith((message) => updates(message as Route)) as Route;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Route create() => Route._();
  @$core.override
  Route createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Route getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Route>(create);
  static Route? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get routeId => $_getSZ(0);
  @$pb.TagNumber(1)
  set routeId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRouteId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRouteId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<LatLon> get geometry => $_getList(1);

  @$pb.TagNumber(3)
  $core.double get distanceMeters => $_getN(2);
  @$pb.TagNumber(3)
  set distanceMeters($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDistanceMeters() => $_has(2);
  @$pb.TagNumber(3)
  void clearDistanceMeters() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get durationSeconds => $_getN(3);
  @$pb.TagNumber(4)
  set durationSeconds($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDurationSeconds() => $_has(3);
  @$pb.TagNumber(4)
  void clearDurationSeconds() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<Maneuver> get maneuvers => $_getList(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
