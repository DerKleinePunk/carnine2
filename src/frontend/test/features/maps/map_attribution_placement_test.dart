import 'package:carnine_frontend/features/maps/presentation/maps_content.dart';
import 'package:carnine_frontend/features/maps/presentation/widgets/trip_status_bar.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_map/local_map.dart';

/// The map's part of the 1024x600 panel: right of the 96 px side menu, below
/// the 40 px top bar.
const _mapOrigin = Offset(96, 40);
const _mapSize = Size(928, 560);

/// In panel pixels (karte-navigation.png, 0.14.0): the compass button ends at
/// y 432.
const _compassBottom = 432.0;

/// The trip bar casts its shadow about 18 px upwards (blur 24, offset -6).
/// On the display the credit showed doubled while inside it (Michael,
/// 2026-10-10), though not in a screenshot.
const _shadowReach = 18.0;

void main() {
  test('following the car goes to zoom 16, not the overview of the route', () {
    expect(MapsContent.mapConfig.followZoom, 16);
  });

  testWidgets(
    'the map credit (OpenMapTiles, OpenStreetMap) shows in German, bottom right, between compass and trip bar',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const insets = MapsContent.tripBarInsets;
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
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: _mapSize,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: MapAttribution.fromConfig(MapsContent.mapConfig),
                  ),
                  Positioned(
                    left: insets.left,
                    right: insets.right,
                    bottom: insets.bottom,
                    child: TripStatusBar(
                      remainingMeters: 1000,
                      remainingSeconds: 60,
                      share: 0.5,
                      onCancel: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      // The localizations load asynchronously.
      await tester.pump();

      final text = find.text('© OpenMapTiles © OpenStreetMap-Mitwirkende');
      expect(text, findsOneWidget, reason: 'readable without a tap');
      final box = tester
          .getRect(
            find.ancestor(of: text, matching: find.byType(DecoratedBox)).first,
          )
          .shift(_mapOrigin);
      final tripBarTop = tester
          .getRect(find.byType(TripStatusBar))
          .shift(_mapOrigin)
          .top;
      expect(
        box.bottom,
        lessThanOrEqualTo(tripBarTop - _shadowReach),
        reason: 'out of the trip bar shadow',
      );
      expect(box.top, greaterThanOrEqualTo(_compassBottom));
      expect(box.right, closeTo(_mapOrigin.dx + _mapSize.width - 8, 0.5));
    },
  );
}
