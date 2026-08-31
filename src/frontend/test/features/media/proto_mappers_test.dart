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
    test('maps every backend event string', () {
      const cases = {
        'snapshot': PlayerEventKind.snapshot,
        'position_changed': PlayerEventKind.positionChanged,
        'playback_started': PlayerEventKind.playbackStarted,
        'resumed': PlayerEventKind.resumed,
        'paused': PlayerEventKind.paused,
        'stopped': PlayerEventKind.stopped,
        'track_changed': PlayerEventKind.trackChanged,
        'error': PlayerEventKind.error,
      };

      for (final entry in cases.entries) {
        expect(playerEventKindFrom(entry.key), entry.value, reason: entry.key);
      }
    });

    test('maps an unrecognised event to unknown', () {
      expect(playerEventKindFrom('some_future_event'), PlayerEventKind.unknown);
    });
  });

  group('playerEventFromProto', () {
    test('resolves state when the proto event carries one', () {
      final event = PlayerEvent(
        event: 'snapshot',
        state: PlayerState(
          status: 'playing',
          mediaPath: '/music/a.mp3',
          positionMs: Int64(1000),
          durationMs: Int64(0),
          playlistId: Int64(7),
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
    });

    test('state is null when the proto event has none set', () {
      final event = PlayerEvent(event: 'error', message: 'boom');

      final update = playerEventFromProto(event);

      expect(update.kind, PlayerEventKind.error);
      expect(update.state, isNull);
    });
  });

  group('libraryScanEventKindFrom', () {
    test('maps every backend event string', () {
      const cases = {
        'scan_started': LibraryScanEventKind.scanStarted,
        'progress': LibraryScanEventKind.progress,
        'error': LibraryScanEventKind.error,
        'scan_completed': LibraryScanEventKind.scanCompleted,
      };

      for (final entry in cases.entries) {
        expect(libraryScanEventKindFrom(entry.key), entry.value,
            reason: entry.key);
      }
    });

    test('maps an unrecognised event to unknown', () {
      expect(libraryScanEventKindFrom('something_else'),
          LibraryScanEventKind.unknown);
    });
  });
}
