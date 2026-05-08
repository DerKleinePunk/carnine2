import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carnine_frontend/app/carnine_app.dart';

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
}
