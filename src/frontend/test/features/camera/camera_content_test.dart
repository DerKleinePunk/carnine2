import 'dart:async';

import 'package:carnine_frontend/data/services/carnine_grpc_service.dart';
import 'package:carnine_frontend/features/camera/data/camera_settings_store.dart';
import 'package:carnine_frontend/features/camera/presentation/camera_content.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_grabber/video_grabber.dart';

class FakeCameraSettingsStore implements CameraSettingsStore {
  FakeCameraSettingsStore({this.config, this.error});

  final GrabberConfig? config;
  final Object? error;
  Completer<void>? gate;

  @override
  Future<GrabberConfig> loadCameraSettings() async {
    await gate?.future;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return config ?? const GrabberConfig();
  }
}

/// A source that only records what happens to it.
class FakeGrabberSource implements GrabberSource {
  FakeGrabberSource(this.config);

  final GrabberConfig config;
  final ValueNotifier<GrabberState> _state = ValueNotifier(
    const GrabberState(GrabberStatus.connecting),
  );
  int starts = 0;
  bool disposed = false;

  void show(GrabberStatus status) => _state.value = GrabberState(status);

  @override
  ValueListenable<GrabberState> get state => _state;

  @override
  Future<void> start() async => starts++;

  @override
  Future<void> stop() async {}

  @override
  Widget buildPicture(BuildContext context) =>
      const ColoredBox(key: ValueKey('fake-picture'), color: Colors.green);

  @override
  Future<void> dispose() async => disposed = true;
}

class Harness {
  final List<FakeGrabberSource> sources = <FakeGrabberSource>[];

  GrabberSource create(GrabberConfig config) {
    final source = FakeGrabberSource(config);
    sources.add(source);
    return source;
  }
}

Widget app(Widget child, {Locale locale = const Locale('de')}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

/// Shows or hides the camera page, as switching pages in the dashboard does.
class PageSwitch extends StatefulWidget {
  const PageSwitch({required this.camera, super.key});

  final Widget camera;

  @override
  State<PageSwitch> createState() => PageSwitchState();
}

class PageSwitchState extends State<PageSwitch> {
  bool showCamera = true;

  void toggle() => setState(() => showCamera = !showCamera);

  @override
  Widget build(BuildContext context) =>
      showCamera ? widget.camera : const Text('other page');
}

void main() {
  testWidgets('opens the camera with the settings from the backend', (
    tester,
  ) async {
    final harness = Harness();
    const config = GrabberConfig(
      device: '/dev/video2',
      input: 4,
      norm: VideoNorm.pal,
    );

    await tester.pumpWidget(
      app(
        CameraContent(
          settingsStore: FakeCameraSettingsStore(config: config),
          sourceFactory: harness.create,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.sources, hasLength(1));
    expect(harness.sources.single.config, config);
    expect(harness.sources.single.starts, 1);
    harness.sources.single.show(GrabberStatus.playing);
    await tester.pump();
    expect(find.byKey(const ValueKey('fake-picture')), findsOneWidget);
    expect(find.byKey(const ValueKey('grabber-message')), findsNothing);
  });

  testWidgets('waits for the settings before it opens the camera', (
    tester,
  ) async {
    final harness = Harness();
    final store = FakeCameraSettingsStore()..gate = Completer<void>();

    await tester.pumpWidget(
      app(CameraContent(settingsStore: store, sourceFactory: harness.create)),
    );
    await tester.pump();

    expect(harness.sources, isEmpty);
    expect(find.text('Verbinde mit der Kamera …'), findsOneWidget);

    store.gate?.complete();
    await tester.pumpAndSettle();
    expect(harness.sources, hasLength(1));
  });

  testWidgets('without the backend the camera opens with the defaults', (
    tester,
  ) async {
    final harness = Harness();

    await tester.pumpWidget(
      app(
        CameraContent(
          settingsStore: FakeCameraSettingsStore(error: StateError('down')),
          sourceFactory: harness.create,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.sources.single.config, const GrabberConfig());
    expect(harness.sources.single.config.norm, VideoNorm.ntsc);
  });

  testWidgets('shows the hints in the UI language', (tester) async {
    final harness = Harness();
    await tester.pumpWidget(app(CameraContent(sourceFactory: harness.create)));
    await tester.pumpAndSettle();
    final source = harness.sources.single;

    final expected = <GrabberStatus, String>{
      GrabberStatus.connecting: 'Verbinde mit der Kamera …',
      GrabberStatus.noSignal: 'Kein Kamerasignal',
      GrabberStatus.deviceMissing: 'Kamera nicht angeschlossen',
      GrabberStatus.error: 'Kamera gestört',
    };
    for (final entry in expected.entries) {
      source.show(entry.key);
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget, reason: '${entry.key}');
    }

    await tester.pumpWidget(
      app(
        CameraContent(sourceFactory: harness.create),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    harness.sources.last.show(GrabberStatus.noSignal);
    await tester.pump();
    expect(find.text('No camera signal'), findsOneWidget);
  });

  testWidgets('leaving the page closes the camera, coming back opens it', (
    tester,
  ) async {
    final harness = Harness();
    final key = GlobalKey<PageSwitchState>();
    await tester.pumpWidget(
      app(
        PageSwitch(
          key: key,
          camera: CameraContent(sourceFactory: harness.create),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(harness.sources.single.disposed, isFalse);

    key.currentState!.toggle();
    await tester.pumpAndSettle();
    expect(harness.sources.single.disposed, isTrue);

    key.currentState!.toggle();
    await tester.pumpAndSettle();
    expect(harness.sources, hasLength(2));
    expect(harness.sources.last.disposed, isFalse);
  });

  testWidgets('leaving before the settings came opens no camera', (
    tester,
  ) async {
    final harness = Harness();
    final store = FakeCameraSettingsStore()..gate = Completer<void>();
    final key = GlobalKey<PageSwitchState>();
    await tester.pumpWidget(
      app(
        PageSwitch(
          key: key,
          camera: CameraContent(
            settingsStore: store,
            sourceFactory: harness.create,
          ),
        ),
      ),
    );
    await tester.pump();

    key.currentState!.toggle();
    await tester.pump();
    store.gate?.complete();
    await tester.pumpAndSettle();

    expect(harness.sources, isEmpty);
  });

  test('maps the backend settings onto the grabber', () {
    expect(
      CarnineGrpcService.grabberConfigFrom(
        CameraSettings(
          device: '/dev/video2',
          norm: CameraNorm.CAMERA_NORM_PAL,
          input: 4,
          width: 720,
        ),
      ),
      const GrabberConfig(
        device: '/dev/video2',
        input: 4,
        norm: VideoNorm.pal,
        width: 720,
      ),
    );
    expect(
      CarnineGrpcService.grabberConfigFrom(CameraSettings(width: 640)).width,
      360,
      reason: 'a width the grabber does not offer keeps the default',
    );
    expect(
      CarnineGrpcService.grabberConfigFrom(CameraSettings()),
      const GrabberConfig(),
      reason: 'fields left out keep the defaults',
    );
    expect(
      CarnineGrpcService.grabberConfigFrom(
        CameraSettings(norm: CameraNorm.CAMERA_NORM_UNSPECIFIED),
      ).norm,
      VideoNorm.ntsc,
    );
  });
}
