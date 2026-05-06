import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:carnine_frontend/app/carnine_app.dart';

void main() {
  testWidgets('shows dashboard shell', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CarnineApp());

    expect(find.text('KINETIC'), findsOneWidget);
    expect(find.text('Dashboard Content for Home'), findsOneWidget);
    expect(find.text('gRPC Status: Not connected'), findsOneWidget);
  });
}
