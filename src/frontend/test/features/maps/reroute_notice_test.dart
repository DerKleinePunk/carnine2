import 'package:carnine_frontend/features/maps/presentation/widgets/reroute_notice_card.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(RerouteNotice notice, {Locale locale = const Locale('de')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 24, top: 16),
          child: RerouteNoticeCard(notice: notice),
        ),
      ),
    ),
  );
}

void main() {
  group('which notice (#103)', () {
    test('on the route there is none', () {
      expect(
        rerouteNoticeFor(
          isRerouting: false,
          offRoute: false,
          rerouteError: null,
        ),
        isNull,
      );
    });

    test('while it is calculated again: recalculating', () {
      expect(
        rerouteNoticeFor(isRerouting: true, offRoute: true, rerouteError: null),
        RerouteNotice.recalculating,
      );
    });

    test('recalculating wins over an older error', () {
      expect(
        rerouteNoticeFor(isRerouting: true, offRoute: true, rerouteError: 'x'),
        RerouteNotice.recalculating,
      );
    });

    test('off the route and the last try failed: unavailable', () {
      expect(
        rerouteNoticeFor(
          isRerouting: false,
          offRoute: true,
          rerouteError: 'routing not reachable',
        ),
        RerouteNotice.unavailable,
      );
    });

    test(
      'off the route with nothing started yet: no notice, the turn stays',
      () {
        expect(
          rerouteNoticeFor(
            isRerouting: false,
            offRoute: true,
            rerouteError: null,
          ),
          isNull,
        );
      },
    );

    test('a leftover error back on the route is not shown', () {
      expect(
        rerouteNoticeFor(
          isRerouting: false,
          offRoute: false,
          rerouteError: 'x',
        ),
        isNull,
      );
    });
  });

  group('the card', () {
    testWidgets('says "Route wird neu berechnet …" in the main color', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(RerouteNotice.recalculating));
      await tester.pump();

      expect(find.text('Route wird neu berechnet …'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.sync));
      expect(icon.color, AppColors.primary);
    });

    testWidgets('says that navigation is unavailable, in the error color', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(RerouteNotice.unavailable));
      await tester.pump();

      expect(
        find.text('Route verlassen – Navigation nicht erreichbar'),
        findsOneWidget,
      );
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.warning_amber_rounded),
      );
      expect(icon.color, AppColors.error);
    });

    testWidgets('is as wide as the turn card, so it takes its place', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(RerouteNotice.recalculating));
      await tester.pump();

      final box = tester.getRect(find.byType(RerouteNoticeCard));
      expect(box.width, 220);
      expect(box.topLeft, const Offset(24, 16));
    });

    testWidgets('a screen reader hears it as it comes', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_harness(RerouteNotice.recalculating));
      await tester.pump();

      final node = tester.getSemantics(find.byType(RerouteNoticeCard));
      expect(node.label, 'Route wird neu berechnet …');
      expect(node.flagsCollection.isLiveRegion, isTrue);
      semantics.dispose();
    });
  });

  group('every language fits the card', () {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('${locale.languageCode}: both notices, no overflow, not '
          'taller than a turn card', (tester) async {
        for (final notice in RerouteNotice.values) {
          await tester.pumpWidget(_harness(notice, locale: locale));
          await tester.pump();
          expect(tester.takeException(), isNull);
          // The turn card is about 134 px high; the notice stays below 190.
          expect(
            tester.getRect(find.byType(RerouteNoticeCard)).height,
            lessThan(190),
            reason: '${locale.languageCode} $notice',
          );
        }
      });
    }
  });
}
