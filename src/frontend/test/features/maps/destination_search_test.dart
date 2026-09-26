import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_controller.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_scope.dart';
import 'package:carnine_frontend/features/maps/presentation/widgets/destination_search.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_map/local_map.dart';

Widget _harness(List<GeocoderResult> results, {LatLng? near}) {
  final keyboard = OnScreenKeyboardController();
  addTearDown(keyboard.dispose);
  return MaterialApp(
    locale: const Locale('de'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: OnScreenKeyboardScope(
      controller: keyboard,
      child: Scaffold(
        body: DestinationSearch(
          results: results,
          searching: false,
          near: near,
          onChanged: (_) {},
          onSelected: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a hit shows type, area and distance', (tester) async {
    await tester.pumpWidget(
      _harness([
        GeocoderResult(
          name: 'Hauptstraße',
          location: const LatLng(50.751, 9.270),
          zoom: 14,
          type: 'transportation_name',
          area: 'Alsfeld',
        ),
        GeocoderResult(
          name: 'Hessen',
          location: const LatLng(50.61, 9.03),
          zoom: 4,
          type: 'place',
          detail: 'state',
        ),
      ], near: const LatLng(50.740, 9.270)),
    );
    // The localizations load asynchronously.
    await tester.pump();
    expect(find.text('Straße · Alsfeld · 1,2 km'), findsOneWidget);
    expect(find.text('Gebiet · 22 km'), findsOneWidget);
  });

  testWidgets('without a fix the distance is left out', (tester) async {
    await tester.pumpWidget(
      _harness([
        GeocoderResult(
          name: 'Alsfeld',
          location: const LatLng(50.752, 9.268),
          zoom: 8,
          type: 'place',
          detail: 'town',
        ),
      ]),
    );
    await tester.pump();
    expect(find.text('Ort'), findsOneWidget);
  });
}
