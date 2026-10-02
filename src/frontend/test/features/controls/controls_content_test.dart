import 'dart:ui' as ui;

import 'package:carnine_frontend/features/controls/domain/control.dart';
import 'package:carnine_frontend/features/controls/presentation/controls_content.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_controls_repository.dart';

/// The area the page really gets on the 1024 x 600 panel: next to the side
/// menu (96 wide) and under the top bar (40 high).
const Size _pageArea = Size(928, 560);

Widget _harness(
  FakeControlsRepository? repository, {
  Locale locale = const Locale('de'),
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
        child: SizedBox(
          width: _pageArea.width,
          height: _pageArea.height,
          child: ControlsContent(repository: repository),
        ),
      ),
    ),
  );
}

void _setUpPanel(WidgetTester tester) {
  tester.view.physicalSize = const Size(1024, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _open(
  WidgetTester tester,
  FakeControlsRepository? repository,
) async {
  _setUpPanel(tester);
  await tester.pumpWidget(_harness(repository));
  await tester.pumpAndSettle();
}

FakeControlsRepository _eightSwitches() {
  final controls = eightSwitches();
  return FakeControlsRepository(controls: controls, values: allOff(controls));
}

const _fan = ControlDefinition(
  id: 'fan',
  name: 'Lüfter',
  kind: ControlKind.slider,
);

void main() {
  testWidgets('eight switches fit the page without scrolling (#86)', (
    tester,
  ) async {
    await _open(tester, _eightSwitches());

    final area = Offset.zero & _pageArea;
    for (var i = 1; i <= 8; i++) {
      expect(find.text('Schalter $i'), findsOneWidget);
      final card = tester.getRect(find.byKey(ValueKey<String>('control-sw$i')));
      expect(area.contains(card.topLeft), isTrue, reason: 'sw$i top left');
      expect(area.contains(card.bottomRight), isTrue, reason: 'sw$i bottom');
    }
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, 0);
  });

  testWidgets('the switches are two rows of four, in the listed order', (
    tester,
  ) async {
    await _open(tester, _eightSwitches());

    Offset at(int i) =>
        tester.getTopLeft(find.byKey(ValueKey<String>('control-sw$i')));
    expect(at(2).dy, at(1).dy);
    expect(at(4).dy, at(1).dy);
    expect(at(2).dx, greaterThan(at(1).dx));
    expect(at(4).dx, greaterThan(at(3).dx));
    expect(at(5).dy, greaterThan(at(1).dy));
    expect(at(5).dx, at(1).dx);
    expect(at(8).dy, at(5).dy);
  });

  testWidgets('a tap anywhere on a card switches it', (tester) async {
    final repository = _eightSwitches();
    await _open(tester, repository);

    await tester.tap(find.text('Schalter 3'));
    await tester.pumpAndSettle();

    expect(repository.sets, ['sw3:on']);
    expect(find.text('AN'), findsOneWidget);
    expect(find.text('AUS'), findsNWidgets(7));
  });

  testWidgets('a change from elsewhere shows at once', (tester) async {
    final repository = _eightSwitches();
    await _open(tester, repository);

    repository.push(
      const ControlValue(id: 'sw5', isAvailable: true, isOn: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('AN'), findsOneWidget);
  });

  testWidgets('a control whose module is away is greyed out and inert', (
    tester,
  ) async {
    final repository = _eightSwitches();
    await _open(tester, repository);

    repository.push(const ControlValue(id: 'sw2', isAvailable: false));
    await tester.pumpAndSettle();
    expect(find.text('NICHT ERREICHBAR'), findsOneWidget);

    await tester.tap(find.text('Schalter 2'));
    await tester.pumpAndSettle();
    expect(repository.sets, isEmpty);

    // It comes back by itself.
    repository.push(
      const ControlValue(id: 'sw2', isAvailable: true, isOn: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('NICHT ERREICHBAR'), findsNothing);
    await tester.tap(find.text('Schalter 2'));
    await tester.pumpAndSettle();
    expect(repository.sets, ['sw2:on']);
  });

  testWidgets('the switch tells a screen reader its name and state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = _eightSwitches();
    await _open(tester, repository);
    repository.push(
      const ControlValue(id: 'sw1', isAvailable: true, isOn: true),
    );
    await tester.pumpAndSettle();

    final node = tester.getSemantics(
      find.byKey(const ValueKey<String>('control-sw1')),
    );

    expect(node.label, 'Schalter 1');
    expect(node.value, 'An');
    expect(node.flagsCollection.isToggled, ui.Tristate.isTrue);
    semantics.dispose();
  });

  testWidgets('a slider card shows its value and is dragged to a new one', (
    tester,
  ) async {
    final repository = FakeControlsRepository(
      controls: const [_fan],
      values: const {
        'fan': ControlValue(id: 'fan', isAvailable: true, level: 20),
      },
    );
    await _open(tester, repository);
    expect(find.text('Lüfter'), findsOneWidget);
    expect(find.text('20 %'), findsOneWidget);

    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final sent = repository.sets.map((s) => int.parse(s.split(':').last));
    expect(sent, isNotEmpty);
    expect(sent.last, greaterThan(20));
    expect(find.text('${sent.last} %'), findsOneWidget);
  });

  testWidgets('eight switches and a slider fit without scrolling, the slider '
      'across the whole page', (tester) async {
    final controls = [...eightSwitches(), _fan];
    final repository = FakeControlsRepository(
      controls: controls,
      values: allOff(controls),
    );
    await _open(tester, repository);

    final slider = tester.getRect(
      find.byKey(const ValueKey<String>('control-fan')),
    );
    final lastSwitch = tester.getRect(
      find.byKey(const ValueKey<String>('control-sw8')),
    );
    expect(slider.width, _pageArea.width - 48);
    expect(slider.top, greaterThan(lastSwitch.bottom));
    expect(slider.bottom, lessThanOrEqualTo(_pageArea.height));
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, 0);
  });

  testWidgets('a slider whose module is away does not react', (tester) async {
    final repository = FakeControlsRepository(
      controls: const [_fan],
      values: const {'fan': ControlValue(id: 'fan', isAvailable: false)},
    );
    await _open(tester, repository);

    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(repository.sets, isEmpty);
    expect(find.text('NICHT ERREICHBAR'), findsOneWidget);
  });

  testWidgets('without controls the page says so', (tester) async {
    await _open(tester, FakeControlsRepository());

    expect(find.text('Keine Technik eingerichtet'), findsOneWidget);
  });

  testWidgets('without a backend there is nothing to show either', (
    tester,
  ) async {
    await _open(tester, null);

    expect(find.text('Keine Technik eingerichtet'), findsOneWidget);
  });

  testWidgets('a change that fails shows a message that goes by itself', (
    tester,
  ) async {
    final repository = _eightSwitches();
    await _open(tester, repository);
    repository.setError = StateError('module away');

    await tester.tap(find.text('Schalter 1'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Befehl fehlgeschlagen'), findsOneWidget);
    expect(find.text('AN'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Befehl fehlgeschlagen'), findsNothing);
  });

  testWidgets('a backend that is away shows a retry, and the page comes back', (
    tester,
  ) async {
    final repository = _eightSwitches()..loadError = StateError('down');
    _setUpPanel(tester);
    await tester.pumpWidget(_harness(repository));
    await tester.pump();
    await tester.pump();

    expect(find.text('Erneut versuchen'), findsOneWidget);
    expect(find.text('Schalter 1'), findsNothing);

    repository.loadError = null;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();

    expect(find.text('Schalter 1'), findsOneWidget);
  });

  testWidgets('the names stay as the user typed them in every language', (
    tester,
  ) async {
    _setUpPanel(tester);
    final controls = [
      const ControlDefinition(
        id: 'a',
        name: 'Innenlicht',
        kind: ControlKind.toggle,
      ),
    ];
    final repository = FakeControlsRepository(
      controls: controls,
      values: allOff(controls),
    );

    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_harness(repository, locale: locale));
      await tester.pumpAndSettle();

      expect(
        find.text('Innenlicht'),
        findsOneWidget,
        reason: locale.toString(),
      );
    }
  });

  group('every language fits the page at 1024x600', () {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('${locale.languageCode}: switches, slider, away, failure', (
        tester,
      ) async {
        _setUpPanel(tester);
        final controls = [
          ...eightSwitches()
              .take(6)
              .map(
                (c) => ControlDefinition(
                  id: c.id,
                  name: 'Ein sehr langer Name der Technik ${c.id}',
                  kind: c.kind,
                ),
              ),
          _fan,
        ];
        final repository = FakeControlsRepository(
          controls: controls,
          values: {
            ...allOff(controls),
            'sw2': const ControlValue(id: 'sw2', isAvailable: false),
            'fan': const ControlValue(id: 'fan', isAvailable: false),
            'sw3': const ControlValue(id: 'sw3', isAvailable: true, isOn: true),
          },
        );
        await tester.pumpWidget(_harness(repository, locale: locale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // The failure strip on top as well.
        repository.setError = StateError('boom');
        await tester.tap(find.byKey(const ValueKey<String>('control-sw1')));
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 5));
      });
    }
  });
}
