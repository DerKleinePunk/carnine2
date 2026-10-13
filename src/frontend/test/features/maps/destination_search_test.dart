import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_controller.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_scope.dart';
import 'package:carnine_frontend/features/maps/presentation/widgets/destination_search.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_map/local_map.dart';

Widget _harness(
  List<GeocoderResult> results, {
  LatLng? near,
  String? shown,
  ValueChanged<String>? onChanged,
}) {
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
          shownDestination: shown,
          onChanged: onChanged ?? (_) {},
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

  group('the destination of the replay route (#127)', () {
    String fieldText(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('the name stands in the field and starts no search', (
      tester,
    ) async {
      final searches = <String>[];
      await tester.pumpWidget(
        _harness(const [], shown: 'Kunsthalle Montez', onChanged: searches.add),
      );
      await tester.pump();

      expect(find.text('Kunsthalle Montez'), findsOneWidget);
      expect(searches, isEmpty);
    });

    testWidgets('the name that arrives later is written without a search', (
      tester,
    ) async {
      final searches = <String>[];
      await tester.pumpWidget(_harness(const [], onChanged: searches.add));
      await tester.pump();
      expect(fieldText(tester), isEmpty);

      await tester.pumpWidget(
        _harness(const [], shown: 'Kunsthalle Montez', onChanged: searches.add),
      );
      await tester.pump();

      expect(fieldText(tester), 'Kunsthalle Montez');
      expect(searches, isEmpty);
    });

    testWidgets('after Abbrechen the field is empty again, without a search', (
      tester,
    ) async {
      final searches = <String>[];
      await tester.pumpWidget(
        _harness(const [], shown: 'Kunsthalle Montez', onChanged: searches.add),
      );
      await tester.pump();

      await tester.pumpWidget(_harness(const [], onChanged: searches.add));
      await tester.pump();

      expect(fieldText(tester), isEmpty);
      expect(searches, isEmpty);
    });

    testWidgets('a destination chosen meanwhile is not wiped', (tester) async {
      await tester.pumpWidget(_harness(const [], shown: 'Kunsthalle Montez'));
      await tester.pump();
      tester.widget<TextField>(find.byType(TextField)).controller!.text =
          'Alsfeld';

      await tester.pumpWidget(_harness(const []));
      await tester.pump();

      expect(fieldText(tester), 'Alsfeld');
    });

    testWidgets('the X clears the name and asks for no results, a typed '
        'text searches as always', (tester) async {
      final searches = <String>[];
      await tester.pumpWidget(
        _harness(const [], shown: 'Kunsthalle Montez', onChanged: searches.add),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(fieldText(tester), isEmpty);
      expect(searches.last, '');

      tester.widget<TextField>(find.byType(TextField)).controller!.text =
          'Haupt';
      await tester.pump();
      expect(searches.last, 'Haupt');
    });

    testWidgets('the same name again does not write the field twice', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const [], shown: 'Kunsthalle Montez'));
      await tester.pump();
      tester.widget<TextField>(find.byType(TextField)).controller!.text =
          'Kunsthalle Montez, Honsellstraße';

      await tester.pumpWidget(_harness(const [], shown: 'Kunsthalle Montez'));
      await tester.pump();

      // Nothing changed on the page, so the user's edit stays.
      expect(fieldText(tester), 'Kunsthalle Montez, Honsellstraße');
    });
  });
}
