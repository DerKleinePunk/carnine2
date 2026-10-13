import 'package:carnine_frontend/features/controls/domain/control.dart';
import 'package:carnine_frontend/features/controls/presentation/controls_content.dart';
import 'package:carnine_frontend/features/controls/presentation/widgets/fitted_name.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_controls_repository.dart';

/// Ahem draws every character as a square of the font size, so what fits is
/// plain arithmetic: 176 px hold 176 / size characters per line.
const _ahem = TextStyle(fontFamily: 'Ahem', fontSize: 18);

double _fit(String text, {double width = 176, double smallest = 6}) =>
    FittedName.fittingFontSize(
      text,
      style: _ahem,
      maxWidth: width,
      maxLines: 2,
      largest: 18,
      smallest: smallest,
    );

void main() {
  group('the font size that keeps every word whole (#96)', () {
    test('a short name keeps the full size', () {
      expect(_fit('Licht'), 18);
      expect(_fit('Ein Licht'), 18);
    });

    test('a name of two words uses two lines before it shrinks', () {
      // "Zusatzlicht vorne" is 17 characters: one line at 10 px or less, but
      // "Zusatzlicht" / "vorne" are two lines at 18 px only if "Zusatzlicht"
      // (11 characters = 198 px) fits - it does not, so it shrinks to 16.
      expect(_fit('Zusatzlicht vorne'), 16);
    });

    test('a word wider than the card shrinks until it fits', () {
      // "Zusatzscheinwerfer": 18 characters in 176 px = 9.77 px at most.
      expect(_fit('Zusatzscheinwerfer'), 9.5);
    });

    test('a third line makes it shrink too', () {
      // "Zusatz Licht vorne" is three lines at 18 px. At 16 px it is "Zusatz"
      // and "Licht vorne" (11 characters = 176 px, just enough); at 16.5 px
      // that line is 181.5 px, and it is three again.
      expect(_fit('Zusatz Licht vorne'), 16);
    });

    test('below the smallest size it stops there', () {
      expect(_fit('Zusatzscheinwerfer', smallest: 12), 12);
    });

    test('with no usable width it leaves the size alone', () {
      expect(_fit('Zusatzscheinwerfer', width: 0), 18);
      expect(_fit('Zusatzscheinwerfer', width: double.infinity), 18);
    });

    test('a name with extra spaces counts words, not spaces', () {
      expect(_fit('  Licht   vorne  '), 18);
    });
  });

  group('on the cards', () {
    Future<void> open(
      WidgetTester tester,
      List<ControlDefinition> controls,
    ) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
          home: Scaffold(
            body: SizedBox(
              width: 928,
              height: 560,
              child: ControlsContent(
                repository: FakeControlsRepository(
                  controls: controls,
                  values: allOff(controls),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    double sizeOf(WidgetTester tester, String name) =>
        tester.widget<Text>(find.text(name)).style!.fontSize!;

    testWidgets('a long name gets a smaller font on its switch, a short one '
        'keeps the full size', (tester) async {
      await open(tester, const [
        ControlDefinition(
          id: 'a',
          name: 'Zusatzscheinwerfer',
          kind: ControlKind.toggle,
        ),
        ControlDefinition(id: 'b', name: 'Licht', kind: ControlKind.toggle),
      ]);

      expect(sizeOf(tester, 'Zusatzscheinwerfer'), lessThan(18));
      expect(sizeOf(tester, 'Licht'), 18);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the same on a slider', (tester) async {
      await open(tester, const [
        ControlDefinition(
          id: 'a',
          name: 'Zusatzscheinwerferhelligkeit',
          kind: ControlKind.slider,
        ),
      ]);

      expect(sizeOf(tester, 'Zusatzscheinwerferhelligkeit'), lessThan(18));
      expect(tester.takeException(), isNull);
    });
  });
}
