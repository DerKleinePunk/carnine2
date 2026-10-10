import 'package:carnine_frontend/features/maps/presentation/maps_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_map/local_map.dart';

/// The map's part of the 1024x600 panel: right of the 96 px side menu, below
/// the 40 px top bar.
const _mapOrigin = Offset(96, 40);
const _mapSize = Size(928, 560);

/// In panel pixels (karte-navigation.png, 0.14.0): the trip panel starts at
/// y 480, the compass button ends at y 432.
const _tripPanelTop = 480.0;
const _compassBottom = 432.0;

void main() {
  testWidgets(
    'the map credit (OpenMapTiles, OpenStreetMap) shows in German, bottom right, between compass and trip panel',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: _mapSize,
              child: MapAttribution.fromConfig(MapsContent.mapConfig),
            ),
          ),
        ),
      );

      final text = find.text('© OpenMapTiles © OpenStreetMap-Mitwirkende');
      expect(text, findsOneWidget, reason: 'readable without a tap');
      final box = tester
          .getRect(
            find.ancestor(of: text, matching: find.byType(DecoratedBox)).first,
          )
          .shift(_mapOrigin);
      expect(box.bottom, lessThanOrEqualTo(_tripPanelTop));
      expect(box.top, greaterThanOrEqualTo(_compassBottom));
      expect(box.right, closeTo(_mapOrigin.dx + _mapSize.width - 8, 0.5));
    },
  );
}
