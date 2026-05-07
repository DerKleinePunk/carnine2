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

    expect(find.text('Sprache'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<Locale>));
    await tester.pumpAndSettle();

    expect(find.text('Französisch'), findsOneWidget);
    expect(find.text('Spanisch'), findsOneWidget);
    expect(find.text('Italienisch'), findsOneWidget);
    expect(find.text('Chinesisch'), findsOneWidget);
    expect(find.text('Japanisch'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Controls'), findsOneWidget);
    expect(find.text('Dashboard content for Settings'), findsNothing);
  });
}
