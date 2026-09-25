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

import 'package:protobuf/protobuf.dart' as $pb;

class LibraryEventType extends $pb.ProtobufEnum {
  static const LibraryEventType LIBRARY_EVENT_TYPE_UNSPECIFIED =
      LibraryEventType._(
          0, _omitEnumNames ? '' : 'LIBRARY_EVENT_TYPE_UNSPECIFIED');
  static const LibraryEventType LIBRARY_SCAN_STARTED =
      LibraryEventType._(1, _omitEnumNames ? '' : 'LIBRARY_SCAN_STARTED');
  static const LibraryEventType LIBRARY_PROGRESS =
      LibraryEventType._(2, _omitEnumNames ? '' : 'LIBRARY_PROGRESS');
  static const LibraryEventType LIBRARY_ERROR =
      LibraryEventType._(3, _omitEnumNames ? '' : 'LIBRARY_ERROR');
  static const LibraryEventType LIBRARY_SCAN_COMPLETED =
      LibraryEventType._(4, _omitEnumNames ? '' : 'LIBRARY_SCAN_COMPLETED');
  static const LibraryEventType LIBRARY_MUSIC_FOUND =
      LibraryEventType._(5, _omitEnumNames ? '' : 'LIBRARY_MUSIC_FOUND');
  static const LibraryEventType LIBRARY_IMPORT_STARTED =
      LibraryEventType._(6, _omitEnumNames ? '' : 'LIBRARY_IMPORT_STARTED');
  static const LibraryEventType LIBRARY_IMPORT_PROGRESS =
      LibraryEventType._(7, _omitEnumNames ? '' : 'LIBRARY_IMPORT_PROGRESS');
  static const LibraryEventType LIBRARY_IMPORT_COMPLETED =
      LibraryEventType._(8, _omitEnumNames ? '' : 'LIBRARY_IMPORT_COMPLETED');
  static const LibraryEventType PLAYLIST_CREATED =
      LibraryEventType._(9, _omitEnumNames ? '' : 'PLAYLIST_CREATED');
  static const LibraryEventType PLAYLIST_ENTRY_ADDED =
      LibraryEventType._(10, _omitEnumNames ? '' : 'PLAYLIST_ENTRY_ADDED');

  static const $core.List<LibraryEventType> values = <LibraryEventType>[
    LIBRARY_EVENT_TYPE_UNSPECIFIED,
    LIBRARY_SCAN_STARTED,
    LIBRARY_PROGRESS,
    LIBRARY_ERROR,
    LIBRARY_SCAN_COMPLETED,
    LIBRARY_MUSIC_FOUND,
    LIBRARY_IMPORT_STARTED,
    LIBRARY_IMPORT_PROGRESS,
    LIBRARY_IMPORT_COMPLETED,
    PLAYLIST_CREATED,
    PLAYLIST_ENTRY_ADDED,
  ];

  static final $core.List<LibraryEventType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 10);
  static LibraryEventType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const LibraryEventType._(super.value, super.name);
}

class PlayerEventType extends $pb.ProtobufEnum {
  static const PlayerEventType PLAYER_EVENT_TYPE_UNSPECIFIED =
      PlayerEventType._(
          0, _omitEnumNames ? '' : 'PLAYER_EVENT_TYPE_UNSPECIFIED');
  static const PlayerEventType PLAYER_SNAPSHOT =
      PlayerEventType._(1, _omitEnumNames ? '' : 'PLAYER_SNAPSHOT');
  static const PlayerEventType PLAYER_POSITION_CHANGED =
      PlayerEventType._(2, _omitEnumNames ? '' : 'PLAYER_POSITION_CHANGED');
  static const PlayerEventType PLAYER_PLAYBACK_STARTED =
      PlayerEventType._(3, _omitEnumNames ? '' : 'PLAYER_PLAYBACK_STARTED');
  static const PlayerEventType PLAYER_RESUMED =
      PlayerEventType._(4, _omitEnumNames ? '' : 'PLAYER_RESUMED');
  static const PlayerEventType PLAYER_PAUSED =
      PlayerEventType._(5, _omitEnumNames ? '' : 'PLAYER_PAUSED');
  static const PlayerEventType PLAYER_STOPPED =
      PlayerEventType._(6, _omitEnumNames ? '' : 'PLAYER_STOPPED');
  static const PlayerEventType PLAYER_TRACK_CHANGED =
      PlayerEventType._(7, _omitEnumNames ? '' : 'PLAYER_TRACK_CHANGED');
  static const PlayerEventType PLAYER_ERROR =
      PlayerEventType._(8, _omitEnumNames ? '' : 'PLAYER_ERROR');
  static const PlayerEventType PLAYER_QUEUE_FINISHED =
      PlayerEventType._(9, _omitEnumNames ? '' : 'PLAYER_QUEUE_FINISHED');

  static const $core.List<PlayerEventType> values = <PlayerEventType>[
    PLAYER_EVENT_TYPE_UNSPECIFIED,
    PLAYER_SNAPSHOT,
    PLAYER_POSITION_CHANGED,
    PLAYER_PLAYBACK_STARTED,
    PLAYER_RESUMED,
    PLAYER_PAUSED,
    PLAYER_STOPPED,
    PLAYER_TRACK_CHANGED,
    PLAYER_ERROR,
    PLAYER_QUEUE_FINISHED,
  ];

  static final $core.List<PlayerEventType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 9);
  static PlayerEventType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PlayerEventType._(super.value, super.name);
}

class RepeatMode extends $pb.ProtobufEnum {
  static const RepeatMode REPEAT_MODE_UNSPECIFIED =
      RepeatMode._(0, _omitEnumNames ? '' : 'REPEAT_MODE_UNSPECIFIED');
  static const RepeatMode REPEAT_OFF =
      RepeatMode._(1, _omitEnumNames ? '' : 'REPEAT_OFF');
  static const RepeatMode REPEAT_QUEUE =
      RepeatMode._(2, _omitEnumNames ? '' : 'REPEAT_QUEUE');
  static const RepeatMode REPEAT_TRACK =
      RepeatMode._(3, _omitEnumNames ? '' : 'REPEAT_TRACK');

  static const $core.List<RepeatMode> values = <RepeatMode>[
    REPEAT_MODE_UNSPECIFIED,
    REPEAT_OFF,
    REPEAT_QUEUE,
    REPEAT_TRACK,
  ];

  static final $core.List<RepeatMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static RepeatMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RepeatMode._(super.value, super.name);
}

class AudioEventType extends $pb.ProtobufEnum {
  static const AudioEventType AUDIO_EVENT_TYPE_UNSPECIFIED =
      AudioEventType._(0, _omitEnumNames ? '' : 'AUDIO_EVENT_TYPE_UNSPECIFIED');
  static const AudioEventType AUDIO_READY =
      AudioEventType._(1, _omitEnumNames ? '' : 'AUDIO_READY');
  static const AudioEventType AUDIO_SOURCE_STARTED =
      AudioEventType._(2, _omitEnumNames ? '' : 'AUDIO_SOURCE_STARTED');
  static const AudioEventType AUDIO_SOURCE_PAUSE_REQUESTED =
      AudioEventType._(3, _omitEnumNames ? '' : 'AUDIO_SOURCE_PAUSE_REQUESTED');
  static const AudioEventType AUDIO_SOURCE_RESUME_REQUESTED = AudioEventType._(
      4, _omitEnumNames ? '' : 'AUDIO_SOURCE_RESUME_REQUESTED');
  static const AudioEventType AUDIO_SOURCE_STOP_REQUESTED =
      AudioEventType._(5, _omitEnumNames ? '' : 'AUDIO_SOURCE_STOP_REQUESTED');
  static const AudioEventType AUDIO_DECODER_STOPPED =
      AudioEventType._(6, _omitEnumNames ? '' : 'AUDIO_DECODER_STOPPED');
  static const AudioEventType AUDIO_SOURCE_REMOVED =
      AudioEventType._(7, _omitEnumNames ? '' : 'AUDIO_SOURCE_REMOVED');
  static const AudioEventType AUDIO_DEVICE_CHANGED =
      AudioEventType._(8, _omitEnumNames ? '' : 'AUDIO_DEVICE_CHANGED');
  static const AudioEventType AUDIO_ERROR =
      AudioEventType._(9, _omitEnumNames ? '' : 'AUDIO_ERROR');

  static const $core.List<AudioEventType> values = <AudioEventType>[
    AUDIO_EVENT_TYPE_UNSPECIFIED,
    AUDIO_READY,
    AUDIO_SOURCE_STARTED,
    AUDIO_SOURCE_PAUSE_REQUESTED,
    AUDIO_SOURCE_RESUME_REQUESTED,
    AUDIO_SOURCE_STOP_REQUESTED,
    AUDIO_DECODER_STOPPED,
    AUDIO_SOURCE_REMOVED,
    AUDIO_DEVICE_CHANGED,
    AUDIO_ERROR,
  ];

  static final $core.List<AudioEventType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 9);
  static AudioEventType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AudioEventType._(super.value, super.name);
}

class FixState extends $pb.ProtobufEnum {
  static const FixState FIX_STATE_UNSPECIFIED =
      FixState._(0, _omitEnumNames ? '' : 'FIX_STATE_UNSPECIFIED');

  /// Source is alive but has no valid position; PositionFix.location is unset.
  static const FixState FIX_STATE_NO_FIX =
      FixState._(1, _omitEnumNames ? '' : 'FIX_STATE_NO_FIX');
  static const FixState FIX_STATE_FIX =
      FixState._(2, _omitEnumNames ? '' : 'FIX_STATE_FIX');

  static const $core.List<FixState> values = <FixState>[
    FIX_STATE_UNSPECIFIED,
    FIX_STATE_NO_FIX,
    FIX_STATE_FIX,
  ];

  static final $core.List<FixState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static FixState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const FixState._(super.value, super.name);
}

class PositionSourceKind extends $pb.ProtobufEnum {
  static const PositionSourceKind POSITION_SOURCE_KIND_UNSPECIFIED =
      PositionSourceKind._(
          0, _omitEnumNames ? '' : 'POSITION_SOURCE_KIND_UNSPECIFIED');
  static const PositionSourceKind POSITION_SOURCE_NONE =
      PositionSourceKind._(1, _omitEnumNames ? '' : 'POSITION_SOURCE_NONE');
  static const PositionSourceKind POSITION_SOURCE_SERIAL =
      PositionSourceKind._(2, _omitEnumNames ? '' : 'POSITION_SOURCE_SERIAL');
  static const PositionSourceKind POSITION_SOURCE_REPLAY =
      PositionSourceKind._(3, _omitEnumNames ? '' : 'POSITION_SOURCE_REPLAY');

  static const $core.List<PositionSourceKind> values = <PositionSourceKind>[
    POSITION_SOURCE_KIND_UNSPECIFIED,
    POSITION_SOURCE_NONE,
    POSITION_SOURCE_SERIAL,
    POSITION_SOURCE_REPLAY,
  ];

  static final $core.List<PositionSourceKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static PositionSourceKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PositionSourceKind._(super.value, super.name);
}

class PlaceType extends $pb.ProtobufEnum {
  static const PlaceType PLACE_TYPE_UNSPECIFIED =
      PlaceType._(0, _omitEnumNames ? '' : 'PLACE_TYPE_UNSPECIFIED');
  static const PlaceType PLACE_TYPE_PLACE =
      PlaceType._(1, _omitEnumNames ? '' : 'PLACE_TYPE_PLACE');
  static const PlaceType PLACE_TYPE_POI =
      PlaceType._(2, _omitEnumNames ? '' : 'PLACE_TYPE_POI');
  static const PlaceType PLACE_TYPE_MOUNTAIN_PEAK =
      PlaceType._(3, _omitEnumNames ? '' : 'PLACE_TYPE_MOUNTAIN_PEAK');
  static const PlaceType PLACE_TYPE_WATER_NAME =
      PlaceType._(4, _omitEnumNames ? '' : 'PLACE_TYPE_WATER_NAME');
  static const PlaceType PLACE_TYPE_TRANSPORTATION_NAME =
      PlaceType._(5, _omitEnumNames ? '' : 'PLACE_TYPE_TRANSPORTATION_NAME');

  static const $core.List<PlaceType> values = <PlaceType>[
    PLACE_TYPE_UNSPECIFIED,
    PLACE_TYPE_PLACE,
    PLACE_TYPE_POI,
    PLACE_TYPE_MOUNTAIN_PEAK,
    PLACE_TYPE_WATER_NAME,
    PLACE_TYPE_TRANSPORTATION_NAME,
  ];

  static final $core.List<PlaceType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static PlaceType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PlaceType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
