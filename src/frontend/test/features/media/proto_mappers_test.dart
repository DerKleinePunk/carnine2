import 'package:carnine_frontend/features/media/data/proto_mappers.dart';
import 'package:carnine_frontend/features/media/domain/models/library_scan_event.dart';
import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';
import 'package:carnine_frontend/features/media/domain/models/player_event_update.dart';
import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('idFrom/durationFrom', () {
    test('converts a positive Int64 to int and milliseconds', () {
      expect(idFrom(Int64(42)), 42);
      expect(durationFrom(Int64(1500)), const Duration(milliseconds: 1500));
    });

    test('clamps a negative duration to zero', () {
      expect(durationFrom(Int64(-1)), Duration.zero);
    });

    test('zero stays zero', () {
      expect(durationFrom(Int64(0)), Duration.zero);
    });
  });

  group('mediaAvailabilityFrom', () {
    test('maps known backend status strings', () {
      expect(mediaAvailabilityFrom('AVAILABLE'), MediaAvailability.available);
      expect(mediaAvailabilityFrom('OFFLINE'), MediaAvailability.offline);
      expect(mediaAvailabilityFrom('MISSING'), MediaAvailability.missing);
    });

    test('maps an unrecognised status to unknown', () {
      expect(mediaAvailabilityFrom('weird'), MediaAvailability.unknown);
      expect(mediaAvailabilityFrom(''), MediaAvailability.unknown);
    });
  });

  group('trackFromProto', () {
    test('maps every field', () {
      final item = MediaItem(
        id: Int64(7),
        sourceId: Int64(2),
        path: '/music/a.mp3',
        title: 'A',
        artist: 'B',
        durationMs: Int64(60000),
        status: 'AVAILABLE',
        hasCoverArt: true,
      );

      final track = trackFromProto(item);

      expect(track.id, 7);
      expect(track.sourceId, 2);
      expect(track.path, '/music/a.mp3');
      expect(track.title, 'A');
      expect(track.artist, 'B');
      expect(track.duration, const Duration(minutes: 1));
      expect(track.availability, MediaAvailability.available);
      expect(track.isPlayable, isTrue);
      expect(track.hasCoverArt, isTrue);
    });
  });

  group('repeatModeFrom/repeatModeToProto', () {
    test('maps every backend repeat mode', () {
      expect(repeatModeFrom(RepeatMode.REPEAT_OFF), MediaRepeatMode.off);
      expect(repeatModeFrom(RepeatMode.REPEAT_QUEUE), MediaRepeatMode.queue);
      expect(repeatModeFrom(RepeatMode.REPEAT_TRACK), MediaRepeatMode.track);
    });

    test('maps the unspecified mode to off', () {
      expect(
        repeatModeFrom(RepeatMode.REPEAT_MODE_UNSPECIFIED),
        MediaRepeatMode.off,
      );
    });

    test('round-trips every domain mode back to its proto value', () {
      for (final mode in MediaRepeatMode.values) {
        expect(repeatModeFrom(repeatModeToProto(mode)), mode);
      }
    });
  });

  group('playbackStatusFrom', () {
    test('maps known status strings', () {
      expect(playbackStatusFrom('playing'), PlaybackStatus.playing);
      expect(playbackStatusFrom('paused'), PlaybackStatus.paused);
      expect(playbackStatusFrom('stopped'), PlaybackStatus.stopped);
    });

    test('falls back to stopped for anything unexpected', () {
      expect(playbackStatusFrom('weird'), PlaybackStatus.stopped);
    });
  });

  group('playerEventKindFrom', () {
    test('maps every backend event enum', () {
      const cases = {
        PlayerEventType.PLAYER_SNAPSHOT: PlayerEventKind.snapshot,
        PlayerEventType.PLAYER_POSITION_CHANGED:
            PlayerEventKind.positionChanged,
        PlayerEventType.PLAYER_PLAYBACK_STARTED:
            PlayerEventKind.playbackStarted,
        PlayerEventType.PLAYER_RESUMED: PlayerEventKind.resumed,
        PlayerEventType.PLAYER_PAUSED: PlayerEventKind.paused,
        PlayerEventType.PLAYER_STOPPED: PlayerEventKind.stopped,
        PlayerEventType.PLAYER_TRACK_CHANGED: PlayerEventKind.trackChanged,
        PlayerEventType.PLAYER_ERROR: PlayerEventKind.error,
      };

      for (final entry in cases.entries) {
        expect(playerEventKindFrom(entry.key), entry.value);
      }
    });

    test('maps the unspecified event to unknown', () {
      expect(
        playerEventKindFrom(PlayerEventType.PLAYER_EVENT_TYPE_UNSPECIFIED),
        PlayerEventKind.unknown,
      );
    });
  });

  group('playerEventFromProto', () {
    test('resolves state when the proto event carries one', () {
      final event = PlayerEvent(
        event: PlayerEventType.PLAYER_SNAPSHOT,
        state: PlayerState(
          status: 'playing',
          mediaPath: '/music/a.mp3',
          positionMs: Int64(1000),
          durationMs: Int64(0),
          playlistId: Int64(7),
          repeatMode: RepeatMode.REPEAT_TRACK,
          shuffleEnabled: true,
        ),
        message: 'current player state',
      );

      final update = playerEventFromProto(event);

      expect(update.kind, PlayerEventKind.snapshot);
      expect(update.state, isNotNull);
      expect(update.state!.status, PlaybackStatus.playing);
      expect(update.state!.mediaPath, '/music/a.mp3');
      expect(update.state!.position, const Duration(seconds: 1));
      expect(update.state!.playlistId, 7);
      expect(update.state!.repeatMode, MediaRepeatMode.track);
      expect(update.state!.shuffleEnabled, isTrue);
    });

    test('state is null when the proto event has none set', () {
      final event = PlayerEvent(
        event: PlayerEventType.PLAYER_ERROR,
        message: 'boom',
      );

      final update = playerEventFromProto(event);

      expect(update.kind, PlayerEventKind.error);
      expect(update.state, isNull);
    });
  });

  group('libraryScanEventKindFrom', () {
    test('maps every backend event enum', () {
      const cases = {
        LibraryEventType.LIBRARY_SCAN_STARTED: LibraryScanEventKind.scanStarted,
        LibraryEventType.LIBRARY_PROGRESS: LibraryScanEventKind.progress,
        LibraryEventType.LIBRARY_ERROR: LibraryScanEventKind.error,
        LibraryEventType.LIBRARY_SCAN_COMPLETED:
            LibraryScanEventKind.scanCompleted,
      };

      for (final entry in cases.entries) {
        expect(libraryScanEventKindFrom(entry.key), entry.value);
      }
    });

    test('maps the unspecified event to unknown', () {
      expect(
        libraryScanEventKindFrom(
          LibraryEventType.LIBRARY_EVENT_TYPE_UNSPECIFIED,
        ),
        LibraryScanEventKind.unknown,
      );
    });
  });
}
