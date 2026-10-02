import 'package:carnine_frontend/core/keyboard/keyboard_panel.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/features/media/domain/media_backend_exception.dart';
import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_wide_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_media_repository.dart';
import '../../fakes/media_test_harness.dart';

const _trackA = MediaLibraryTrack(
  id: 1,
  sourceId: 1,
  path: '/music/a.mp3',
  title: 'Neon Dreams',
  artist: 'Cyberpunk Orchestra',
  duration: Duration(minutes: 4, seconds: 56),
  availability: MediaAvailability.available,
);

/// An entry whose file is gone from the library: no track to resolve.
const _knownEntry = MediaPlaylistEntry(
  id: 1,
  playlistId: 7,
  mediaId: 1,
  position: 0,
  track: _trackA,
);
const _goneEntry = MediaPlaylistEntry(
  id: 2,
  playlistId: 7,
  mediaId: 99,
  position: 1,
  track: null,
);

void main() {
  late FakeMediaRepository repository;
  late MediaController controller;

  setUp(() {
    repository = FakeMediaRepository()..library = const [_trackA];
    repository.playlists = const [
      MediaPlaylist(id: 7, name: 'Drive', entries: []),
    ];
    repository.playlistDetails[7] = const MediaPlaylist(
      id: 7,
      name: 'Drive',
      entries: [_knownEntry, _goneEntry],
    );
    controller = MediaController(
      repository: repository,
      heartbeatInterval: null,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  Future<void> openDetail(WidgetTester tester) async {
    setUpMediaView(tester);
    await tester.pumpWidget(mediaHarness(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAMMLUNGEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Playlist Drive öffnen'));
    await tester.pumpAndSettle();
  }

  void typeName(WidgetTester tester, String name) {
    // OnScreenTextField is bound to the on-screen keyboard, not the platform
    // IME, so tester.enterText cannot drive it.
    tester
            .widget<OnScreenTextField>(find.byType(OnScreenTextField))
            .controller
            .text =
        name;
  }

  String fieldText(WidgetTester tester) => tester
      .widget<OnScreenTextField>(find.byType(OnScreenTextField))
      .controller
      .text;

  group('detail page', () {
    testWidgets('offers rename, delete and a cross on every entry', (
      tester,
    ) async {
      await openDetail(tester);

      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      // The entry without a track can be taken out as well.
      expect(find.byIcon(Icons.close), findsNWidgets(2));
    });

    testWidgets('delete asks first and removes the playlist on Löschen', (
      tester,
    ) async {
      await openDetail(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Playlist löschen?'), findsOneWidget);
      expect(
        find.textContaining('„Drive“ wird endgültig gelöscht'),
        findsOneWidget,
      );
      expect(repository.commands, isNot(contains('deletePlaylist:7')));

      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();

      expect(repository.commands, contains('deletePlaylist:7'));
      // Back on the overview, which has no playlist left.
      expect(find.text('Noch keine Playlists angelegt'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('Abbrechen leaves the playlist alone', (tester) async {
      await openDetail(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(repository.commands, isNot(contains('deletePlaylist:7')));
      expect(find.text('DRIVE'), findsOneWidget);
    });

    testWidgets('the cross takes the entry out at once, without asking', (
      tester,
    ) async {
      await openDetail(tester);
      expect(find.text('Neon Dreams'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(repository.commands, contains('removePlaylistEntry:1'));
      expect(find.text('Neon Dreams'), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('an entry whose track is gone can be removed too', (
      tester,
    ) async {
      await openDetail(tester);

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();

      expect(repository.commands, contains('removePlaylistEntry:2'));
      expect(find.text('Titel nicht mehr in der Bibliothek'), findsNothing);
      expect(find.text('Neon Dreams'), findsOneWidget);
    });
  });

  group('rename page', () {
    testWidgets('starts with the current name and saves the new one', (
      tester,
    ) async {
      await openDetail(tester);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      expect(find.text('PLAYLIST UMBENENNEN'), findsOneWidget);
      expect(fieldText(tester), 'Drive');

      typeName(tester, 'Road');
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(repository.commands, contains('renamePlaylist:7:Road'));
      // Back on the detail page, under the new name.
      expect(find.text('ROAD'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('Speichern is greyed out while the name is empty', (
      tester,
    ) async {
      await openDetail(tester);
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      typeName(tester, '');
      await tester.pump();

      expect(
        tester.widget<MediaWideButton>(find.byType(MediaWideButton)).isEnabled,
        isFalse,
      );
    });

    testWidgets('a name another playlist has shows the duplicate error', (
      tester,
    ) async {
      await openDetail(tester);
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      repository.playlists = const [
        MediaPlaylist(id: 7, name: 'Drive', entries: []),
        MediaPlaylist(id: 8, name: 'Road', entries: []),
      ];
      typeName(tester, 'Road');
      await tester.pump();
      repository.nextError = const MediaBackendException(
        MediaErrorKind.alreadyExists,
        'dup',
      );
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(
        find.text('Eine Playlist mit diesem Namen existiert bereits'),
        findsOneWidget,
      );
      expect(find.text('PLAYLIST UMBENENNEN'), findsOneWidget);
    });

    testWidgets('the button stays above the open on-screen keyboard', (
      tester,
    ) async {
      await openDetail(tester);
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.byType(KeyboardPanel), findsOneWidget);
      final button = tester.getRect(find.byType(MediaWideButton));
      final keyboard = tester.getRect(find.byType(KeyboardPanel));
      expect(button.bottom, lessThanOrEqualTo(keyboard.top));
    });

    testWidgets('back returns to the detail page without a call', (
      tester,
    ) async {
      await openDetail(tester);
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('DRIVE'), findsOneWidget);
      expect(
        repository.commands.where((c) => c.startsWith('renamePlaylist')),
        isEmpty,
      );
    });
  });

  group('create page (#31)', () {
    Future<void> openCreate(WidgetTester tester) async {
      setUpMediaView(tester);
      await tester.pumpWidget(mediaHarness(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAMMLUNGEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
    }

    testWidgets('has an Erstellen button, greyed out without a name', (
      tester,
    ) async {
      await openCreate(tester);

      expect(find.text('Erstellen'), findsOneWidget);
      expect(
        tester.widget<MediaWideButton>(find.byType(MediaWideButton)).isEnabled,
        isFalse,
      );

      typeName(tester, 'Night');
      await tester.pump();

      expect(
        tester.widget<MediaWideButton>(find.byType(MediaWideButton)).isEnabled,
        isTrue,
      );
    });

    testWidgets('Erstellen creates the playlist without the keyboard', (
      tester,
    ) async {
      await openCreate(tester);
      typeName(tester, 'Night');
      await tester.pump();

      await tester.tap(find.text('Erstellen'));
      await tester.pumpAndSettle();

      expect(repository.playlists.map((p) => p.name), contains('Night'));
      // Handed off to adding tracks, as with Fertig on the keyboard.
      expect(find.byType(OnScreenTextField), findsWidgets);
    });
  });
}
