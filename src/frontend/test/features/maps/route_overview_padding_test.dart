import 'package:carnine_frontend/features/maps/presentation/maps_content.dart';
import 'package:carnine_frontend/features/maps/presentation/widgets/trip_status_bar.dart';
import 'package:carnine_frontend/features/maps/presentation/widgets/turn_by_turn_card.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_map/local_map.dart';

/// The map's part of the 1024x600 panel: right of the 96 px side menu, below
/// the 40 px top bar.
const _mapSize = Size(928, 560);

void main() {
  test('the map hands its overview padding to local_map', () {
    expect(MapsContent.mapConfig.overviewPadding, MapsContent.overviewPadding);
  });

  testWidgets(
    'the route overview keeps start and destination clear of the turn card '
    'above and the trip bar below',
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
                  // Where MapsContent puts them while a route is active.
                  const Positioned(
                    top: 16,
                    left: 24,
                    child: TurnByTurnCard(
                      maneuver: RoutingManeuver(
                        instruction: 'Rechts auf Kennedyallee abbiegen.',
                        lengthKm: 0.7,
                        timeSeconds: 60,
                        type: 10,
                        streetNames: ['Kennedyallee'],
                      ),
                      meters: 720,
                    ),
                  ),
                  Positioned(
                    left: insets.left,
                    right: insets.right,
                    bottom: insets.bottom,
                    child: TripStatusBar(
                      remainingMeters: 5800,
                      remainingSeconds: 480,
                      share: 0.2,
                      onCancel: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final card = tester.getRect(find.byType(TurnByTurnCard));
      final bar = tester.getRect(find.byType(TripStatusBar));
      const padding = MapsContent.overviewPadding;

      expect(padding.top, greaterThan(card.bottom), reason: 'turn card $card');
      expect(
        padding.bottom,
        greaterThan(_mapSize.height - bar.top),
        reason: 'trip bar $bar',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
