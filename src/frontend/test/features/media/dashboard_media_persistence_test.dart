import 'package:carnine_frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/dashboard_screen.dart';
import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/domain/models/player_event_update.dart';
import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_media_repository.dart';

const _trackA = MediaLibraryTrack(
  id: 1,
  sourceId: 1,
  path: '/music/a.mp3',
  title: 'Neon Dreams',
  artist: 'Cyberpunk Orchestra',
  duration: Duration(minutes: 4),
  availability: MediaAvailability.available,
);

const _trackB = MediaLibraryTrack(
  id: 2,
  sourceId: 1,
  path: '/music/b.mp3',
  title: 'Synthetic Rain',
  artist: 'Glitch Void',
  duration: Duration(minutes: 3),
  availability: MediaAvailability.available,
);

void main() {
  testWidgets(
      'the media queue survives navigating away from Medien and back',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = FakeMediaRepository()..library = const [_trackA, _trackB];
    final mediaController = MediaController(repository: repository);
    final dashboardController = DashboardController();
    addTearDown(mediaController.dispose);
    addTearDown(dashboardController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: DashboardScreen(
          languageController: AppLanguageController(),
          controller: dashboardController,
          mediaController: mediaController,
        ),
      ),
    );
    await tester.pump();

    // Go to Medien and load a two-track playlist queue.
    dashboardController.selectItem(2);
    await tester.pump();

    await mediaController.player.playPlaylist(
      const MediaPlaylist(id: 5, name: 'Drive', entries: []),
      const [_trackA, _trackB],
    );
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
    await tester.pump();

    expect(mediaController.player.queue.tracks, hasLength(2));

    // Navigate to another sidebar section and back.
    dashboardController.selectItem(0);
    await tester.pump();
    dashboardController.selectItem(2);
    await tester.pump();

    // The SAME controller instance is still alive and still holds the queue -
    // this is the actual regression this test guards.
    expect(mediaController.player.queue.tracks, hasLength(2));
    expect(find.text('SYNTHETIC RAIN'), findsWidgets);

    // Stop the playback ticker so no periodic timer is left running past
    // teardown.
    repository.playerEventsController.add(
      const PlayerEventUpdate(
        kind: PlayerEventKind.paused,
        state: PlayerSnapshot(
          status: PlaybackStatus.paused,
          mediaPath: '/music/a.mp3',
          position: Duration.zero,
        ),
        message: 'playback paused',
      ),
    );
    await tester.pump();
  });
}
