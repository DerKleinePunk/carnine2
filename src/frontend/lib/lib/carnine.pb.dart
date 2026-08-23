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

class PlayerState extends $pb.GeneratedMessage {
  factory PlayerState({
    $core.String? status,
    $core.String? mediaPath,
    $fixnum.Int64? positionMs,
    $fixnum.Int64? durationMs,
  }) {
    final result = create();
    if (status != null) result.status = status;
    if (mediaPath != null) result.mediaPath = mediaPath;
    if (positionMs != null) result.positionMs = positionMs;
    if (durationMs != null) result.durationMs = durationMs;
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

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
