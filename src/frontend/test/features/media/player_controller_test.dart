import 'package:carnine_frontend/features/media/domain/media_backend_exception.dart';
import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/domain/models/player_event_update.dart';
import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';
import 'package:carnine_frontend/features/media/presentation/player_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_media_repository.dart';

const _trackA = MediaLibraryTrack(
  id: 1,
  sourceId: 1,
  path: '/music/a.mp3',
  title: 'A',
  artist: 'Artist A',
  duration: Duration(minutes: 5),
  availability: MediaAvailability.available,
);

const _trackB = MediaLibraryTrack(
  id: 2,
  sourceId: 1,
  path: '/music/b.mp3',
  title: 'B',
  artist: 'Artist B',
  duration: Duration(minutes: 4),
  availability: MediaAvailability.available,
);

const _trackMissing = MediaLibraryTrack(
  id: 3,
  sourceId: 1,
  path: '/music/missing.mp3',
  title: 'Missing',
  artist: 'Artist C',
  duration: Duration(minutes: 3),
  availability: MediaAvailability.missing,
);

void main() {
  late FakeMediaRepository repository;
  late PlayerController controller;

  setUp(() {
    repository = FakeMediaRepository()
      ..library = const [_trackA, _trackB, _trackMissing];
    controller = PlayerController(repository: repository);
  });

  tearDown(() {
    controller.dispose();
  });

  test('snapshot event seeds status, position and the current track', () async {
    await controller.start();

    repository.playerEventsController.add(
      PlayerEventUpdate(
        kind: PlayerEventKind.snapshot,
        state: const PlayerSnapshot(
          status: PlaybackStatus.paused,
          mediaPath: '/music/a.mp3',
          position: Duration(seconds: 30),
        ),
        message: 'current player state',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.status, PlaybackStatus.paused);
    expect(controller.currentTrack?.title, 'A');
    expect(controller.position, const Duration(seconds: 30));
  });

  test('a position_changed event corrects the anchor instead of adding to it',
      () {
    fakeAsync((async) {
      controller.start();
      async.flushMicrotasks();

      repository.playerEventsController.add(
        PlayerEventUpdate(
          kind: PlayerEventKind.playbackStarted,
          state: const PlayerSnapshot(
            status: PlaybackStatus.playing,
            mediaPath: '/music/a.mp3',
            position: Duration.zero,
          ),
          message: 'playback started',
        ),
      );
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 1));
      expect(controller.position, const Duration(seconds: 1));

      // The backend reports position_changed once per second, always
      // wall-clock authoritative. If the local ticker were also
      // accumulating, this would land on 2s instead of 1s.
      repository.playerEventsController.add(
        PlayerEventUpdate(
          kind: PlayerEventKind.positionChanged,
          state: const PlayerSnapshot(
            status: PlaybackStatus.playing,
            mediaPath: '/music/a.mp3',
            position: Duration(seconds: 1),
          ),
          message: 'playback position updated',
        ),
      );
      async.flushMicrotasks();

      expect(controller.position, const Duration(seconds: 1));
    });
  });

  test('position clamps at the known track duration', () {
    fakeAsync((async) {
      controller.start();
      async.flushMicrotasks();

      repository.playerEventsController.add(
        PlayerEventUpdate(
          kind: PlayerEventKind.playbackStarted,
          state: const PlayerSnapshot(
            status: PlaybackStatus.playing,
            mediaPath: '/music/a.mp3',
            // Already past the track's 5 minute duration - the backend
            // never notices end-of-track (finding 0.4 in the plan).
            position: Duration(minutes: 6),
          ),
          message: 'playback started',
        ),
      );
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));

      expect(controller.position, const Duration(minutes: 5));
    });
  });

  test('ticker stops on paused', () {
    fakeAsync((async) {
      controller.start();
      async.flushMicrotasks();

      repository.playerEventsController.add(
        PlayerEventUpdate(
          kind: PlayerEventKind.playbackStarted,
          state: const PlayerSnapshot(
            status: PlaybackStatus.playing,
            mediaPath: '/music/a.mp3',
            position: Duration.zero,
          ),
          message: 'playback started',
        ),
      );
      async.flushMicrotasks();

      repository.playerEventsController.add(
        PlayerEventUpdate(
          kind: PlayerEventKind.paused,
          state: const PlayerSnapshot(
            status: PlaybackStatus.paused,
            mediaPath: '/music/a.mp3',
            position: Duration(seconds: 2),
          ),
          message: 'playback paused',
        ),
      );
      async.flushMicrotasks();

      final pausedPosition = controller.position;
      async.elapse(const Duration(seconds: 5));

      expect(controller.position, pausedPosition);
      expect(controller.isPlaying, isFalse);
    });
  });

  test('a stopped event keeps the current track sticky', () async {
    await controller.start();

    repository.playerEventsController.add(
      PlayerEventUpdate(
        kind: PlayerEventKind.snapshot,
        state: const PlayerSnapshot(
          status: PlaybackStatus.playing,
          mediaPath: '/music/a.mp3',
          position: Duration(seconds: 10),
        ),
        message: 'snapshot',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.currentTrack?.title, 'A');

    repository.playerEventsController.add(
      const PlayerEventUpdate(
          kind: PlayerEventKind.stopped, state: null, message: 'stopped'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.status, PlaybackStatus.stopped);
    expect(controller.currentTrack?.title, 'A',
        reason: 'track should stay sticky after stop');
    expect(controller.position, Duration.zero);
  });

  test('playTrack on an unplayable track sends no command', () async {
    await controller.start();

    await controller.playTrack(_trackMissing);

    expect(repository.commands, isEmpty);
  });

  test('playTrack issues stop then play, in order', () async {
    await controller.start();

    await controller.playTrack(_trackA);

    expect(repository.commands, ['stop', 'play:/music/a.mp3']);
  });

  test('playPlaylist issues playPlaylist then an empty play, in order',
      () async {
    await controller.start();
    const playlist = MediaPlaylist(id: 5, name: 'Drive', entries: []);

    await controller.playPlaylist(playlist, [_trackA]);

    expect(repository.commands, ['playPlaylist:5', 'play:']);
  });

  test('playQueueEntry sends the selected queue index', () async {
    await controller.start();
    const playlist = MediaPlaylist(id: 5, name: 'Drive', entries: []);

    await controller.playPlaylist(playlist, [_trackA, _trackB]);
    await controller.playQueueEntry(1);

    expect(repository.commands, [
      'playPlaylist:5',
      'play:',
      'playQueueEntry:1',
    ]);
  });

  test('playQueueEntry ignores invalid indices', () async {
    await controller.start();
    const playlist = MediaPlaylist(id: 5, name: 'Drive', entries: []);

    await controller.playPlaylist(playlist, [_trackA]);
    await controller.playQueueEntry(1);

    expect(repository.commands, ['playPlaylist:5', 'play:']);
  });

  test(
      'a precondition error on next() shows a hint but does not report offline',
      () async {
    var offlineReported = false;
    final controllerWithCallback = PlayerController(
      repository: repository,
      onStreamFailure: (_) => offlineReported = true,
    );
    await controllerWithCallback.start();

    const playlist = MediaPlaylist(id: 5, name: 'Drive', entries: []);
    await controllerWithCallback.playPlaylist(playlist, [_trackA, _trackB]);
    // Put the player at the first of two tracks, so canGoNext is true and
    // next() actually attempts the call.
    repository.playerEventsController.add(
      PlayerEventUpdate(
        kind: PlayerEventKind.playbackStarted,
        state: const PlayerSnapshot(
          status: PlaybackStatus.playing,
          mediaPath: '/music/a.mp3',
          position: Duration.zero,
        ),
        message: 'playback started',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controllerWithCallback.canGoNext, isTrue);

    repository.nextError =
        const MediaBackendException(MediaErrorKind.precondition, 'queue end');
    await controllerWithCallback.next();

    expect(controllerWithCallback.transientMessageKey,
        AppTextKey.mediaNoAdjacentTrack);
    expect(offlineReported, isFalse);

    controllerWithCallback.dispose();
  });

  test(
      'a slow command (deadlineExceeded -> unknown) shows a hint but does '
      'not report offline or tear down the channel', () async {
    var offlineReported = false;
    final controllerWithCallback = PlayerController(
      repository: repository,
      onStreamFailure: (_) => offlineReported = true,
    );
    await controllerWithCallback.start();

    // Simulates Stop/Next/Previous outliving the client's call deadline
    // while the backend is still waiting for external audio processes to
    // exit (e.g. under WSL) - the connection itself is fine.
    repository.nextError =
        const MediaBackendException(MediaErrorKind.unknown, 'slow');
    await controllerWithCallback.playTrack(_trackA);

    expect(controllerWithCallback.transientMessageKey,
        AppTextKey.mediaCommandFailed);
    expect(offlineReported, isFalse);

    controllerWithCallback.dispose();
  });
}
