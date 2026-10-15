import 'dart:async';
import 'dart:io';

import 'package:carnine_frontend/app/app_theme.dart';
import 'package:carnine_frontend/features/controls/domain/control.dart';
import 'package:carnine_frontend/features/dashboard/data/cpu_temperature_source.dart';
import 'package:carnine_frontend/features/dashboard/data/power_supply_source.dart';
import 'package:carnine_frontend/features/dashboard/data/thermal_status_source.dart';
import 'package:carnine_frontend/features/dashboard/presentation/cpu_temperature_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
import 'package:carnine_frontend/features/dashboard/presentation/power_supply_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/thermal_warning_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/home/home_content.dart';
import 'package:carnine_frontend/features/maps/data/navigation_channel.dart';
import 'package:carnine_frontend/features/maps/presentation/maps_controller.dart';
import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';
import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/player_event_update.dart';
import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/control_button.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/play_pause_button.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

import '../../fakes/fake_controls_repository.dart';
import '../../fakes/fake_media_repository.dart';

class _PowerSource implements PowerSupplySource {
  final StreamController<PowerSupplyStatus> controller =
      StreamController<PowerSupplyStatus>.broadcast();

  @override
  Stream<PowerSupplyStatus> get statuses => controller.stream;

  @override
  Future<void> dispose() => controller.close();
}

class _ThermalSource implements ThermalStatusSource {
  final StreamController<ThermalStatus> controller =
      StreamController<ThermalStatus>.broadcast();

  @override
  Stream<ThermalStatus> get statuses => controller.stream;

  @override
  Future<void> dispose() => controller.close();
}

class _CpuSource implements CpuTemperatureSource {
  final StreamController<double?> controller =
      StreamController<double?>.broadcast();

  @override
  Stream<double?> get temperatures => controller.stream;

  @override
  Future<void> dispose() => controller.close();
}

const _track = MediaLibraryTrack(
  id: 1,
  sourceId: 1,
  path: '/music/a.mp3',
  title: 'Nachtfahrt',
  artist: 'Die Landstraße',
  duration: Duration(minutes: 4),
  availability: MediaAvailability.available,
);

const _running = PowerSupplyStatus(
  configured: true,
  connected: true,
  ignition: true,
  state: PowerSupplyState.run,
  inputVolts: 12.6,
);

/// The start page with everything it listens to replaced by hand-made
/// sources; [push] plays what the backend sends.
class _Rig {
  _Rig({this.controls}) {
    maps = MapsController(
      // No backend: every call fails at once, which the controller shrugs off.
      channel: NavigationChannel(
        channelFactory: () => ClientChannel(
          InternetAddress.loopbackIPv4,
          port: 1,
          options: const ChannelOptions(
            credentials: ChannelCredentials.insecure(),
          ),
        ),
      ),
      statusInterval: const Duration(hours: 1),
    );
    media = MediaController(
      repository: mediaRepository,
      heartbeatInterval: null,
    );
    power = PowerSupplyController(source: powerSource)..start();
    thermal = ThermalWarningController(source: thermalSource)..start();
    cpu = CpuTemperatureController(source: cpuSource)..start();
  }

  final FakeControlsRepository? controls;
  final mediaRepository = FakeMediaRepository()..library = const [_track];
  final powerSource = _PowerSource();
  final thermalSource = _ThermalSource();
  final cpuSource = _CpuSource();
  late final MapsController maps;
  late final MediaController media;
  late final PowerSupplyController power;
  late final ThermalWarningController thermal;
  late final CpuTemperatureController cpu;
  final List<DashboardDestination> opened = [];

  Widget app({Locale locale = const Locale('de'), ThemeData? theme}) {
    return MaterialApp(
      theme: theme,
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
          // What the page gets next to the side menu and under the top bar.
          child: SizedBox(
            width: 928,
            height: 560,
            child: HomeContent(
              mapsController: maps,
              mediaController: media,
              powerSupplyController: power,
              thermalWarningController: thermal,
              cpuTemperatureController: cpu,
              controlsRepository: controls,
              onOpen: opened.add,
            ),
          ),
        ),
      ),
    );
  }

  void dispose() {
    maps.dispose();
    media.dispose();
    power.dispose();
    thermal.dispose();
    cpu.dispose();
  }
}

_Rig? _current;

Future<_Rig> _open(
  WidgetTester tester, {
  FakeControlsRepository? controls,
  Locale locale = const Locale('de'),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(1024, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final rig = _current = _Rig(controls: controls);
  await withClock(Clock.fixed(DateTime(2026, 10, 14, 13, 27)), () async {
    await tester.pumpWidget(rig.app(locale: locale, theme: theme));
    await tester.pumpAndSettle();
  });
  return rig;
}

/// Like `testWidgets`, and afterwards closes the page and what it listens
/// to, and lets the timers of the calls that found no backend run out - the
/// test would end with them pending otherwise.
void _test(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      final rig = _current;
      _current = null;
      if (rig != null) {
        await tester.pumpWidget(const SizedBox.shrink());
        rig.dispose();
        await tester.pump(const Duration(seconds: 5));
      }
    }
  });
}

FakeControlsRepository _switches(int count, {bool slider = false}) {
  final controls = [
    for (var i = 1; i <= count; i++)
      ControlDefinition(
        id: 'sw$i',
        name: 'Schalter $i',
        kind: ControlKind.toggle,
      ),
    if (slider)
      const ControlDefinition(
        id: 'fan',
        name: 'Lüfter',
        kind: ControlKind.slider,
      ),
  ];
  return FakeControlsRepository(controls: controls, values: allOff(controls));
}

Color? _color(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  group('time and date', () {
    _test('the time large and the date written out', (tester) async {
      await _open(tester);

      expect(find.text('13:27'), findsOneWidget);
      expect(find.text('Mittwoch, 14. Oktober 2026'), findsOneWidget);
    });

    _test('the date follows the language', (tester) async {
      await _open(tester, locale: const Locale('en'));

      expect(find.text('Wednesday, October 14, 2026'), findsOneWidget);
    });
  });

  group('the navigation tile', () {
    _test('without a route it asks for a destination', (tester) async {
      await _open(tester);

      expect(find.text('NAVIGATION'), findsOneWidget);
      expect(find.text('Ziel eingeben'), findsOneWidget);
    });

    _test('a tap opens the map', (tester) async {
      final rig = await _open(tester);

      await tester.tap(find.text('Ziel eingeben'));

      expect(rig.opened, [DashboardDestination.maps]);
    });
  });

  group('the music tile', () {
    _test('without a track it says so and the buttons are grey', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text('Keine Wiedergabe'), findsOneWidget);
      expect(find.text('Medien öffnen'), findsOneWidget);
      final buttons = tester.widgetList<ControlButton>(
        find.byType(ControlButton),
      );
      expect(buttons, hasLength(2));
      expect(buttons.every((button) => !button.isEnabled), isTrue);
      expect(
        tester.widget<PlayPauseButton>(find.byType(PlayPauseButton)).isEnabled,
        isFalse,
      );
    });

    _test('a tap opens the media page', (tester) async {
      final rig = await _open(tester);

      await tester.tap(find.text('Keine Wiedergabe'));

      expect(rig.opened, [DashboardDestination.media]);
    });

    _test('title, artist and play/pause of the current track', (tester) async {
      final rig = await _open(tester);
      await rig.media.start();
      rig.mediaRepository.playerEventsController.add(
        PlayerEventUpdate(
          kind: PlayerEventKind.snapshot,
          state: const PlayerSnapshot(
            status: PlaybackStatus.paused,
            mediaPath: '/music/a.mp3',
            position: Duration(minutes: 1),
          ),
          message: '',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nachtfahrt'), findsOneWidget);
      expect(find.text('Die Landstraße'), findsOneWidget);
      expect(find.text('Keine Wiedergabe'), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.25, 0.01));

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      expect(rig.mediaRepository.commands, ['play:']);
      // The buttons do not open the page.
      expect(rig.opened, isEmpty);
    });
  });

  group('the quick switches', () {
    _test('the first four switches, the sliders left out', (tester) async {
      final controls = FakeControlsRepository(
        controls: [
          const ControlDefinition(
            id: 'fan',
            name: 'Lüfter',
            kind: ControlKind.slider,
          ),
          for (var i = 1; i <= 6; i++)
            ControlDefinition(
              id: 'sw$i',
              name: 'Schalter $i',
              kind: ControlKind.toggle,
            ),
        ],
      );
      await _open(tester, controls: controls);

      expect(find.text('SCHNELLSCHALTER'), findsOneWidget);
      for (var i = 1; i <= 4; i++) {
        expect(find.text('Schalter $i'), findsOneWidget);
      }
      expect(find.text('Schalter 5'), findsNothing);
      expect(find.text('Lüfter'), findsNothing);
    });

    _test('a tap on one switches it', (tester) async {
      final controls = _switches(3);
      await _open(tester, controls: controls);

      await tester.tap(find.text('Schalter 2'));
      await tester.pumpAndSettle();

      expect(controls.sets, ['sw2:on']);
      expect(find.text('AN'), findsOneWidget);
    });

    _test('one that does not answer is grey and inert', (tester) async {
      final controls = _switches(2);
      await _open(tester, controls: controls);

      controls.push(const ControlValue(id: 'sw1', isAvailable: false));
      await tester.pumpAndSettle();
      expect(find.text('NICHT ERREICHBAR'), findsOneWidget);

      await tester.tap(find.text('Schalter 1'));
      await tester.pumpAndSettle();
      expect(controls.sets, isEmpty);
    });

    _test('without switches the tile is not there', (tester) async {
      await _open(tester, controls: FakeControlsRepository());

      expect(find.text('SCHNELLSCHALTER'), findsNothing);
    });

    _test('with only sliders the tile is not there either', (tester) async {
      final controls = FakeControlsRepository(
        controls: const [
          ControlDefinition(
            id: 'fan',
            name: 'Lüfter',
            kind: ControlKind.slider,
          ),
        ],
      );
      await _open(tester, controls: controls);

      expect(find.text('SCHNELLSCHALTER'), findsNothing);
    });

    _test('without a backend the tile is not there', (tester) async {
      await _open(tester);

      expect(find.text('SCHNELLSCHALTER'), findsNothing);
    });

    _test('the backend is away: no tile, and it comes back', (tester) async {
      final controls = _switches(2)..loadError = StateError('down');
      await _open(tester, controls: controls);
      expect(find.text('SCHNELLSCHALTER'), findsNothing);

      controls.loadError = null;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('SCHNELLSCHALTER'), findsOneWidget);
    });
  });

  group('the vehicle tile', () {
    _test('without a power supply and without a reading it is not '
        'there', (tester) async {
      await _open(tester);

      expect(find.text('FAHRZEUG'), findsNothing);
    });

    _test('without a power supply only the temperature', (tester) async {
      final rig = await _open(tester);

      rig.cpuSource.controller.add(42.4);
      await tester.pumpAndSettle();

      expect(find.text('FAHRZEUG'), findsOneWidget);
      expect(find.text('42 °C'), findsOneWidget);
      expect(find.text('Zündung'), findsNothing);
      expect(find.text('Spannung'), findsNothing);
      expect(_color(tester, '42 °C'), AppColors.onSurface);
    });

    _test('ignition and voltage of a power supply that answers', (
      tester,
    ) async {
      final rig = await _open(tester);

      rig.powerSource.controller.add(_running);
      await tester.pumpAndSettle();

      expect(find.text('Zündung'), findsOneWidget);
      expect(find.text('An'), findsOneWidget);
      expect(find.text('12,6 V'), findsOneWidget);
    });

    _test('ignition off and the supply about to switch off are red', (
      tester,
    ) async {
      final rig = await _open(tester);

      rig.powerSource.controller.add(
        const PowerSupplyStatus(
          configured: true,
          connected: true,
          ignition: false,
          state: PowerSupplyState.powerOff,
          inputVolts: 11.9,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aus'), findsOneWidget);
      expect(_color(tester, 'Aus'), AppColors.error);
      expect(_color(tester, '11,9 V'), AppColors.error);
    });

    _test('a power supply that does not answer says so', (tester) async {
      final rig = await _open(tester);

      rig.powerSource.controller.add(
        const PowerSupplyStatus(configured: true, connected: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Netzteil antwortet nicht'), findsOneWidget);
      expect(find.text('Zündung'), findsNothing);
    });

    _test('overheated: the temperature is red', (tester) async {
      final rig = await _open(tester);

      rig.cpuSource.controller.add(78.2);
      rig.thermalSource.controller.add(
        const ThermalStatus(overheated: true, cpuCelsius: 76.5),
      );
      await tester.pumpAndSettle();

      expect(_color(tester, '78 °C'), AppColors.error);

      rig.thermalSource.controller.add(
        const ThermalStatus(overheated: false, cpuCelsius: 66),
      );
      rig.cpuSource.controller.add(66);
      await tester.pumpAndSettle();

      expect(_color(tester, '66 °C'), AppColors.onSurface);
    });

    _test('overheated without a live reading: the one of the status', (
      tester,
    ) async {
      final rig = await _open(tester);

      rig.thermalSource.controller.add(
        const ThermalStatus(overheated: true, cpuCelsius: 76.5),
      );
      await tester.pumpAndSettle();

      expect(find.text('77 °C'), findsOneWidget);
    });

    _test('a tap does nothing', (tester) async {
      final rig = await _open(tester);
      rig.cpuSource.controller.add(42);
      await tester.pumpAndSettle();

      await tester.tap(find.text('42 °C'));

      expect(rig.opened, isEmpty);
    });
  });

  // Drawn with the real font and theme, like the cards of the Technik page
  // (#96): on jeep-pi "Rundumleuchte" broke into "Rundumleucht" / "e" on the
  // card, four to a row (#94).
  group('long switch names with the real font', () {
    setUpAll(() async {
      final loader = FontLoader('SpaceGrotesk');
      for (final file in Directory('assets/fonts').listSync()) {
        final path = file.path;
        if (path.contains('SpaceGrotesk-') && path.endsWith('.ttf')) {
          final bytes = File(path).readAsBytesSync();
          loader.addFont(Future.value(ByteData.sublistView(bytes)));
        }
      }
      await loader.load();
    });

    /// The words of [name] that the card breaks across two lines.
    List<String> brokenWords(WidgetTester tester, String name) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
      return [
        for (final word in RegExp(r'\S+').allMatches(name))
          if (paragraph
                  .getBoxesForSelection(
                    TextSelection(
                      baseOffset: word.start,
                      extentOffset: word.end,
                    ),
                  )
                  .map((box) => box.top.round())
                  .toSet()
                  .length >
              1)
            word.group(0)!,
      ];
    }

    for (final names in const [
      ['Arbeitslicht', 'Innenlicht', 'Scheinwerfer', 'Rundumleuchte'],
      ['Zusatzscheinwerfer', 'Demo-Licht', 'Relais GPA0', 'Rundumleuchte'],
    ]) {
      _test('${names.join(', ')}: every word whole', (tester) async {
        final controls = [
          for (final name in names)
            ControlDefinition(id: name, name: name, kind: ControlKind.toggle),
        ];
        await _open(
          tester,
          controls: FakeControlsRepository(
            controls: controls,
            values: allOff(controls),
          ),
          theme: CarnineTheme.dark,
        );

        for (final name in names) {
          expect(brokenWords(tester, name), isEmpty, reason: name);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(name),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: name);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('every language fits at 1024x600', () {
    for (final locale in AppLocalizations.supportedLocales) {
      _test('${locale.languageCode}: all tiles full', (tester) async {
        final rig = await _open(tester, controls: _switches(4), locale: locale);
        rig.powerSource.controller.add(_running);
        rig.cpuSource.controller.add(61);
        await rig.media.start();
        rig.mediaRepository.playerEventsController.add(
          PlayerEventUpdate(
            kind: PlayerEventKind.snapshot,
            state: const PlayerSnapshot(
              status: PlaybackStatus.playing,
              mediaPath: '/music/a.mp3',
              position: Duration(seconds: 20),
            ),
            message: '',
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
      });
    }
  });
}
