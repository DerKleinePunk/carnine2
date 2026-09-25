import 'package:carnine_frontend/features/dashboard/presentation/widgets/carnine_top_bar.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;

  Widget clockApp(Locale locale) {
    return MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: TopBarClock()),
    );
  }

  testWidgets('shows the time in 24-hour format for German', (tester) async {
    now = DateTime(2026, 9, 24, 14, 5, 30);
    await withClock(Clock(() => now), () async {
      await tester.pumpWidget(clockApp(const Locale('de')));
    });

    expect(find.text('14:05'), findsOneWidget);
  });

  testWidgets('shows AM/PM for English', (tester) async {
    now = DateTime(2026, 9, 24, 14, 5, 30);
    await withClock(Clock(() => now), () async {
      await tester.pumpWidget(clockApp(const Locale('en')));
    });

    expect(find.text('2:05 PM'), findsOneWidget);
  });

  testWidgets('changes exactly at the next minute boundary', (tester) async {
    now = DateTime(2026, 9, 24, 14, 5, 30);
    await withClock(Clock(() => now), () async {
      await tester.pumpWidget(clockApp(const Locale('de')));

      now = now.add(const Duration(seconds: 29));
      await tester.pump(const Duration(seconds: 29));
      expect(find.text('14:05'), findsOneWidget);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('14:06'), findsOneWidget);

      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('14:07'), findsOneWidget);
    });
  });
}
