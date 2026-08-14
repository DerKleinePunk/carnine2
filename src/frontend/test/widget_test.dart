import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carnine_frontend/app/carnine_app.dart';
import 'package:carnine_frontend/features/media/presentation/media_content.dart';
import 'package:carnine_frontend/styles/colors.dart';

void main() {
  testWidgets('shows dashboard shell', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CarnineApp());
    await tester.pumpAndSettle();

    expect(find.text('CarNine'), findsOneWidget);
    expect(find.text('Technik'), findsOneWidget);
    expect(find.text('CarNiNe'), findsNothing);
    expect(find.text('Dashboard-Inhalt für Start'), findsOneWidget);
    expect(find.text('gRPC-Status: Nicht verbunden'), findsOneWidget);
  });

  testWidgets('opens option pages from the touch grid', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CarnineApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Optionen'));
    await tester.pumpAndSettle();

    expect(find.text('Sprache'), findsWidgets);
    expect(find.text('Diagnose'), findsOneWidget);
    expect(find.text('Darstellung'), findsOneWidget);
    expect(find.text('Karteneinstellungen'), findsOneWidget);
    expect(find.text('Touchoptimierte Fahrzeug- und Systemoptionen.'),
        findsNothing);
    expect(find.byType(GridView), findsNothing);

    await tester.tap(find.text('Diagnose'));
    await tester.pumpAndSettle();

    expect(find.text('Aktuelle Frontend-Logs'), findsOneWidget);
    expect(find.text('Noch keine Logeinträge'), findsOneWidget);
    expect(find.text('Logansicht öffnen'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Optionen'), findsOneWidget);
    expect(find.text('Darstellung'), findsOneWidget);
  });

  testWidgets('switches frontend language in settings', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CarnineApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Optionen'));
    await tester.pumpAndSettle();

    expect(find.text('Sprache'), findsWidgets);

    await tester.tap(find.text('Sprache').first);
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Deutsch'), findsWidgets);
    expect(find.text('English'), findsOneWidget);

    expect(find.text('Dänisch'), findsOneWidget);
    expect(find.text('Französisch'), findsOneWidget);
    expect(find.text('Niederländisch'), findsOneWidget);
    expect(find.text('Polnisch'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsWidgets);
    expect(find.text('Controls'), findsOneWidget);
    expect(find.text('Dashboard content for Settings'), findsNothing);

    final languageGrid = find.byType(GridView);
    final chineseTile = find.descendant(
      of: languageGrid,
      matching: find.text('Chinese'),
    );
    final czechTile = find.descendant(
      of: languageGrid,
      matching: find.text('Czech'),
    );
    final danishTile = find.descendant(
      of: languageGrid,
      matching: find.text('Danish'),
    );

    expect(chineseTile, findsOneWidget);
    expect(czechTile, findsOneWidget);
    expect(danishTile, findsOneWidget);
    expect(
      tester.getTopLeft(chineseTile).dy,
      equals(tester.getTopLeft(czechTile).dy),
    );
    expect(
      tester.getTopLeft(czechTile).dy,
      equals(tester.getTopLeft(danishTile).dy),
    );
    expect(
      tester.getTopLeft(chineseTile).dx,
      lessThan(tester.getTopLeft(czechTile).dx),
    );
    expect(
      tester.getTopLeft(czechTile).dx,
      lessThan(tester.getTopLeft(danishTile).dx),
    );

    await tester.scrollUntilVisible(
      find.text('Turkish'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Hungarian'), findsOneWidget);
    expect(find.text('Polish'), findsOneWidget);
    expect(find.text('Portuguese'), findsOneWidget);
    expect(find.text('Swedish'), findsOneWidget);
    expect(find.text('Turkish'), findsOneWidget);
  });

  testWidgets('plays, pauses and seeks on the media screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The media screen starts an internal playback ticker (`Timer.periodic`),
    // so `pumpAndSettle` (which loops until no frame is scheduled) must not
    // be used here - it would spin forever. Bounded `pump(duration)` calls
    // both advance the fake clock the ticker runs on and render a frame.
    await tester.pumpWidget(const CarnineApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medien'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('NEON DREAMS'), findsWidgets);
    expect(find.text('02:14'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);

    // Playback ticks the position forward automatically once per second.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('02:17'), findsOneWidget);

    // Pausing stops the ticker.
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('02:17'), findsOneWidget);

    // Resuming restarts the ticker.
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('02:19'), findsOneWidget);

    // Manual +/-30s seeking still works on top of the ticked position.
    await tester.tap(find.byIcon(Icons.forward_30));
    await tester.pump();

    expect(find.text('02:49'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.replay_30));
    await tester.pump();

    expect(find.text('02:19'), findsOneWidget);

    // Pause again so no periodic timer is left running past test teardown.
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
  });

  testWidgets('collapses and expands the media queue sidebar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CarnineApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medien'));
    await tester.pump(const Duration(milliseconds: 200));

    // Stop the playback ticker so `pumpAndSettle` is safe to use below.
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsNothing);

    final expandedArtSize = tester.getSize(
      find.byIcon(Icons.graphic_eq_rounded),
    );

    // Collapsing the sidebar hides it and gives the player core more room.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    final collapsedArtSize = tester.getSize(
      find.byIcon(Icons.graphic_eq_rounded),
    );
    expect(collapsedArtSize.width, greaterThan(expandedArtSize.width));

    // Expanding it again restores the original layout.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(
      tester.getSize(find.byIcon(Icons.graphic_eq_rounded)),
      expandedArtSize,
    );
  });

  testWidgets('swipes to open and close the media queue sidebar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CarnineApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medien'));
    await tester.pump(const Duration(milliseconds: 200));

    // Stop the playback ticker so `pumpAndSettle` is safe to use below.
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    // The sidebar starts expanded, so a left-to-right swipe closes it.
    await tester.fling(find.byType(MediaContent), const Offset(300, 0), 800);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    // A right-to-left swipe reopens it.
    await tester.fling(find.byType(MediaContent), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('toggles shuffle and repeat on the media screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CarnineApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medien'));
    await tester.pump(const Duration(milliseconds: 200));

    // Stop the playback ticker so `pumpAndSettle` is safe to use below.
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    Color iconColor(IconData icon) =>
        tester.widget<Icon>(find.byIcon(icon)).color!;

    expect(iconColor(Icons.shuffle), AppColors.primaryDim);
    expect(iconColor(Icons.repeat), AppColors.primaryDim);

    await tester.tap(find.byIcon(Icons.shuffle));
    await tester.pumpAndSettle();

    expect(iconColor(Icons.shuffle), AppColors.primary);
    expect(iconColor(Icons.repeat), AppColors.primaryDim);

    await tester.tap(find.byIcon(Icons.repeat));
    await tester.pumpAndSettle();

    expect(iconColor(Icons.shuffle), AppColors.primary);
    expect(iconColor(Icons.repeat), AppColors.primary);

    await tester.tap(find.byIcon(Icons.shuffle));
    await tester.pumpAndSettle();

    expect(iconColor(Icons.shuffle), AppColors.primaryDim);
    expect(iconColor(Icons.repeat), AppColors.primary);
  });

  testWidgets('opens and closes the media library quick action pages', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CarnineApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medien'));
    await tester.pump(const Duration(milliseconds: 200));

    // Stop the playback ticker so `pumpAndSettle` is safe to use below.
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    expect(find.text('ERSTELLEN'), findsOneWidget);
    expect(find.text('SAMMLUNGEN'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Erstellen vorbereitet'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('ERSTELLEN'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('ERSTELLEN'), findsOneWidget);
    expect(find.text('Erstellen vorbereitet'), findsNothing);

    await tester.tap(find.byIcon(Icons.library_music));
    await tester.pumpAndSettle();

    expect(find.text('Sammlungen vorbereitet'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('SAMMLUNGEN'), findsOneWidget);
    expect(find.text('Sammlungen vorbereitet'), findsNothing);
  });
}
