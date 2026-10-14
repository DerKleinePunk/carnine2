import 'package:carnine_frontend/features/dashboard/presentation/widgets/home/navigation_tile.dart';
import 'package:carnine_frontend/features/maps/presentation/maps_controller.dart';
import 'package:carnine_frontend/features/maps/presentation/widgets/reroute_notice_card.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tile where the left column of the start page puts it: 540 wide, 256
/// high on the 1024 x 600 panel.
const Size _tileSize = Size(540, 256);

Widget _harness(
  NavigationTileView tile, {
  Locale locale = const Locale('de'),
  Size size = _tileSize,
}) {
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
        child: SizedBox(width: size.width, height: size.height, child: tile),
      ),
    ),
  );
}

NavigationTileView _tile({
  GpsState gps = GpsState.fix,
  NavigationTrip? trip,
  bool isRouting = false,
  VoidCallback? onTap,
}) => NavigationTileView(
  gps: gps,
  trip: trip,
  isRouting: isRouting,
  onTap: onTap ?? () {},
);

NavigationTrip _trip({
  RerouteNotice? notice,
  int? maneuverType = 15,
  double? metersToNext = 300,
  String? target = 'L 3181',
  double remainingMeters = 46000,
  int remainingSeconds = 2340,
  DateTime? now,
}) => NavigationTrip(
  notice: notice,
  maneuverType: maneuverType,
  metersToNext: metersToNext,
  target: target,
  remainingMeters: remainingMeters,
  remainingSeconds: remainingSeconds,
  now: now ?? DateTime(2026, 10, 14, 13, 27),
);

Color? _color(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

Future<void> _show(
  WidgetTester tester,
  NavigationTileView tile, {
  Locale locale = const Locale('de'),
}) async {
  tester.view.physicalSize = const Size(1024, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_harness(tile, locale: locale));
  await tester.pumpAndSettle();
}

void main() {
  group('without a route', () {
    testWidgets('it asks for a destination', (tester) async {
      await _show(tester, _tile());

      expect(find.text('Ziel eingeben'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('while one is calculated it says so', (tester) async {
      await _show(tester, _tile(isRouting: true));

      expect(find.text('Route wird berechnet …'), findsOneWidget);
      expect(find.text('Ziel eingeben'), findsNothing);
    });

    testWidgets('a tap is passed on', (tester) async {
      var taps = 0;
      await _show(tester, _tile(onTap: () => taps++));

      await tester.tap(find.text('Ziel eingeben'));

      expect(taps, 1);
    });
  });

  group('with a route', () {
    testWidgets('the next turn, the way to it, what is left, the arrival', (
      tester,
    ) async {
      await _show(tester, _tile(trip: _trip()));

      expect(find.byIcon(Icons.turn_left), findsOneWidget);
      expect(find.text('300 m', findRichText: true), findsOneWidget);
      expect(find.text('L 3181'), findsOneWidget);
      expect(find.text('ANKUNFT'), findsOneWidget);
      // 13:27 and 39 minutes.
      expect(find.text('14:06', findRichText: true), findsOneWidget);
      expect(find.text('DISTANZ'), findsOneWidget);
      expect(find.text('46 km', findRichText: true), findsOneWidget);
      expect(find.text('Ziel eingeben'), findsNothing);
    });

    testWidgets('the instruction stands in for a street without a name', (
      tester,
    ) async {
      await _show(tester, _tile(trip: _trip(target: 'Der Straße folgen')));

      expect(find.text('Der Straße folgen'), findsOneWidget);
    });

    testWidgets('before the first progress only what is left', (tester) async {
      await _show(
        tester,
        _tile(
          trip: _trip(maneuverType: null, metersToNext: null, target: null),
        ),
      );

      expect(find.byIcon(Icons.straight), findsOneWidget);
      expect(find.text('46 km', findRichText: true), findsOneWidget);
    });

    testWidgets('an arrival after midnight says "morgen"', (tester) async {
      await _show(
        tester,
        _tile(
          trip: _trip(
            remainingSeconds: 3 * 3600,
            now: DateTime(2026, 10, 14, 22, 30),
          ),
        ),
      );

      expect(find.text('ANKUNFT MORGEN'), findsOneWidget);
      expect(find.text('01:30', findRichText: true), findsOneWidget);
    });

    testWidgets('while it is calculated again the notice takes the turn\'s '
        'place', (tester) async {
      await _show(
        tester,
        _tile(trip: _trip(notice: RerouteNotice.recalculating)),
      );

      expect(find.text('Route wird neu berechnet …'), findsOneWidget);
      expect(find.byIcon(Icons.turn_left), findsNothing);
      expect(find.text('L 3181'), findsNothing);
      // What is left stays.
      expect(find.text('46 km', findRichText: true), findsOneWidget);
    });

    testWidgets('off the route and unreachable the notice is red', (
      tester,
    ) async {
      await _show(
        tester,
        _tile(trip: _trip(notice: RerouteNotice.unavailable)),
      );

      expect(
        find.text('Route verlassen – Navigation nicht erreichbar'),
        findsOneWidget,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded)).color,
        AppColors.error,
      );
    });
  });

  group('the GPS dot', () {
    testWidgets('with a fix: GPS in the main color', (tester) async {
      await _show(tester, _tile());

      expect(find.text('GPS'), findsOneWidget);
      expect(_color(tester, 'GPS'), AppColors.primary);
    });

    testWidgets('without a fix: red and says so', (tester) async {
      await _show(tester, _tile(gps: GpsState.noFix));

      expect(find.text('Keine GPS-Position'), findsOneWidget);
      expect(_color(tester, 'Keine GPS-Position'), AppColors.error);
      expect(find.text('GPS'), findsNothing);
    });

    testWidgets('without a position source there is no dot', (tester) async {
      await _show(tester, _tile(gps: GpsState.none));

      expect(find.text('GPS'), findsNothing);
      expect(find.text('Keine GPS-Position'), findsNothing);
    });
  });

  group('every language fits the tile', () {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('${locale.languageCode}: route, notice, no route, no fix', (
        tester,
      ) async {
        for (final tile in [
          _tile(
            trip: _trip(
              target: 'Bundesautobahn 661 Richtung Frankfurt-Ost',
              remainingSeconds: 30 * 3600,
              remainingMeters: 498000,
            ),
          ),
          _tile(
            gps: GpsState.noFix,
            trip: _trip(notice: RerouteNotice.unavailable),
          ),
          _tile(gps: GpsState.noFix),
          _tile(isRouting: true),
        ]) {
          await _show(tester, tile, locale: locale);
          expect(tester.takeException(), isNull);
        }
      });
    }
  });
}
