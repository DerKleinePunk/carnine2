import 'dart:async';
import 'dart:io';

import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_controller.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_overlay.dart';
import 'package:carnine_frontend/core/keyboard/on_screen_keyboard_scope.dart';
import 'package:carnine_frontend/features/dashboard/data/power_supply_source.dart';
import 'package:carnine_frontend/features/dashboard/data/thermal_status_source.dart';
import 'package:carnine_frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/dashboard_screen.dart';
import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
import 'package:carnine_frontend/features/dashboard/presentation/power_supply_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/thermal_warning_controller.dart';
import 'package:carnine_frontend/features/maps/data/navigation_channel.dart';
import 'package:carnine_frontend/features/maps/presentation/maps_controller.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart' as pb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

import '../../fakes/fake_media_repository.dart';

/// Backend with only a status: the test says whether the trade fair mode is
/// on.
class _FakeNavigationService extends pb.NavigationServiceBase {
  bool demo = true;

  @override
  Future<pb.NavigationStatus> getNavigationStatus(
    ServiceCall call,
    pb.Empty request,
  ) async => pb.NavigationStatus(demoMode: demo);

  @override
  Stream<pb.PositionFix> streamPositions(ServiceCall call, pb.Empty request) =>
      const Stream.empty();

  @override
  Future<pb.SearchPlacesResponse> searchPlaces(
    ServiceCall call,
    pb.SearchPlacesRequest request,
  ) async => pb.SearchPlacesResponse();

  @override
  Future<pb.ServiceVersion> getServiceVersion(
    ServiceCall call,
    pb.Empty request,
  ) async => pb.ServiceVersion();

  @override
  Future<pb.LocationName> getLocationName(
    ServiceCall call,
    pb.GetLocationNameRequest request,
  ) async => pb.LocationName();

  @override
  Future<pb.Route> computeRoute(
    ServiceCall call,
    pb.ComputeRouteRequest request,
  ) => throw GrpcError.unimplemented();

  @override
  Future<pb.Route> getReplayRoute(
    ServiceCall call,
    pb.GetReplayRouteRequest request,
  ) => throw GrpcError.unimplemented();

  @override
  Future<pb.NavigationStatus> setTrackRecording(
    ServiceCall call,
    pb.SetTrackRecordingRequest request,
  ) => throw GrpcError.unimplemented();

  @override
  Future<pb.Empty> prepareAnnouncements(
    ServiceCall call,
    pb.PrepareAnnouncementsRequest request,
  ) async => pb.Empty();

  @override
  Future<pb.Empty> announce(
    ServiceCall call,
    pb.AnnounceRequest request,
  ) async => pb.Empty();

  @override
  Future<pb.VoiceSettings> getVoiceSettings(
    ServiceCall call,
    pb.Empty request,
  ) => throw GrpcError.unimplemented();

  @override
  Future<pb.VoiceSettings> setVoiceSettings(
    ServiceCall call,
    pb.SetVoiceSettingsRequest request,
  ) => throw GrpcError.unimplemented();
}

class _QuietPowerSupply implements PowerSupplySource {
  @override
  Stream<PowerSupplyStatus> get statuses => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

class _QuietThermal implements ThermalStatusSource {
  @override
  Stream<ThermalStatus> get statuses => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

void main() {
  const minute = Duration(seconds: 60);

  late _FakeNavigationService service;
  late Server server;
  late MapsController maps;
  late MediaController media;
  late DashboardController dashboard;
  late OnScreenKeyboardController keyboard;

  /// A touch on an empty corner of the display.
  Future<void> touch(WidgetTester tester) async {
    final gesture = await tester.startGesture(const Offset(1018, 598));
    await gesture.up();
  }

  /// The backend's answer reaches the controller, and the dashboard hears it.
  Future<void> askBackend(WidgetTester tester) async {
    await tester.runAsync(() async {
      await maps.refreshStatus();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }

  Future<void> start(WidgetTester tester, {bool demo = true}) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    service = _FakeNavigationService()..demo = demo;
    await tester.runAsync(() async {
      server = Server.create(services: [service]);
      await server.serve(address: InternetAddress.loopbackIPv4, port: 0);
      final port = server.port!;
      maps = MapsController(
        channel: NavigationChannel(
          channelFactory: () => ClientChannel(
            InternetAddress.loopbackIPv4,
            port: port,
            options: const ChannelOptions(
              credentials: ChannelCredentials.insecure(),
            ),
          ),
        ),
        statusInterval: const Duration(hours: 1),
      );
    });
    media = MediaController(
      repository: FakeMediaRepository(),
      heartbeatInterval: null,
    );
    dashboard = DashboardController();
    keyboard = OnScreenKeyboardController();
    final power = PowerSupplyController(source: _QuietPowerSupply());
    final thermal = ThermalWarningController(source: _QuietThermal());
    addTearDown(() async {
      media.dispose();
      dashboard.dispose();
      keyboard.dispose();
      power.dispose();
      thermal.dispose();
      await tester.runAsync(() async {
        maps.dispose();
        await server.shutdown();
      });
    });

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
        builder: (context, child) => OnScreenKeyboardScope(
          controller: keyboard,
          child: Stack(
            children: [
              child!,
              OnScreenKeyboardOverlay(controller: keyboard),
            ],
          ),
        ),
        home: DashboardScreen(
          languageController: AppLanguageController(),
          controller: dashboard,
          mediaController: media,
          mapsController: maps,
          powerSupplyController: power,
          thermalWarningController: thermal,
        ),
      ),
    );
    await tester.pump();
    await askBackend(tester);
    // The answer came in on the real clock, so the timer it started did too.
    // A first touch puts it on the test's clock, where it can be waited for.
    await touch(tester);
  }

  DashboardDestination page() => dashboard.selectedItem.destination;

  testWidgets('59 seconds without a touch: it stays, at 60 it is on the map', (
    tester,
  ) async {
    await start(tester);
    dashboard.selectDestination(DashboardDestination.settings);
    await tester.pump();

    await tester.pump(const Duration(seconds: 59));
    expect(page(), DashboardDestination.settings);

    await tester.pump(const Duration(seconds: 1));
    expect(page(), DashboardDestination.maps);
  });

  testWidgets('a touch at 30 seconds gives another 60', (tester) async {
    await start(tester);
    dashboard.selectDestination(DashboardDestination.settings);
    await tester.pump();

    await tester.pump(const Duration(seconds: 30));
    await touch(tester);
    await tester.pump(const Duration(seconds: 59));
    expect(page(), DashboardDestination.settings);

    await tester.pump(const Duration(seconds: 1));
    expect(page(), DashboardDestination.maps);
  });

  testWidgets('without the trade fair mode the device stays where it is', (
    tester,
  ) async {
    await start(tester, demo: false);
    dashboard.selectDestination(DashboardDestination.settings);
    await tester.pump();

    await tester.pump(const Duration(minutes: 10));

    expect(page(), DashboardDestination.settings);
  });

  testWidgets('on the map nothing happens', (tester) async {
    await start(tester);
    dashboard.selectDestination(DashboardDestination.maps);
    await tester.pump();

    await tester.pump(const Duration(minutes: 3));

    expect(page(), DashboardDestination.maps);
  });

  testWidgets('an open dialog holds it, and the minute after it closes '
      'brings the map', (tester) async {
    await start(tester);
    dashboard.selectDestination(DashboardDestination.settings);
    await tester.pump();
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nach Updates suchen'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.pump(minute * 3);
    expect(page(), DashboardDestination.settings);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();
    await tester.pump(minute);

    expect(page(), DashboardDestination.maps);
  });

  testWidgets('an open keyboard holds it', (tester) async {
    await start(tester);
    dashboard.selectDestination(DashboardDestination.settings);
    await tester.pump();
    final text = TextEditingController();
    final focus = FocusNode();
    addTearDown(text.dispose);
    addTearDown(focus.dispose);
    keyboard.requestKeyboard(controller: text, focusNode: focus);
    await tester.pump();
    expect(keyboard.isOpen, isTrue);

    await tester.pump(minute * 3);
    expect(page(), DashboardDestination.settings);

    keyboard.releaseKeyboard(text);
    await tester.pump(minute);
    expect(page(), DashboardDestination.maps);
  });

  testWidgets('a playlist flow in Medien holds it, the player does not', (
    tester,
  ) async {
    await start(tester);
    dashboard.selectDestination(DashboardDestination.media);
    await tester.pump();
    media.showLibraryAction(MediaLibraryAction.create);
    await tester.pump();

    await tester.pump(minute * 3);
    expect(page(), DashboardDestination.media);

    media.closeLibraryAction();
    // The page slides out in 180 ms, and its field gives the keyboard back.
    await tester.pumpAndSettle();
    await tester.pump(minute);
    expect(
      page(),
      DashboardDestination.maps,
      reason: 'after the flow was closed',
    );

    // The list of playlists is no input: it does not hold. (Switching pages
    // takes a tap, which starts the time.)
    dashboard.selectDestination(DashboardDestination.media);
    await touch(tester);
    media.showLibraryAction(MediaLibraryAction.collections);
    await tester.pump();
    await tester.pump(minute);
    expect(
      page(),
      DashboardDestination.maps,
      reason: 'with the playlist list open',
    );
  });

  testWidgets('a touch in a dialog counts as well', (tester) async {
    await start(tester);
    dashboard.selectDestination(DashboardDestination.settings);
    await tester.pump();
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nach Updates suchen'));
    await tester.pumpAndSettle();

    // Touching inside the dialog is outside of the dashboard's widget tree.
    await tester.pump(const Duration(seconds: 50));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AlertDialog)),
    );
    await gesture.up();
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 59));
    expect(page(), DashboardDestination.settings);
    await tester.pump(const Duration(seconds: 1));
    expect(page(), DashboardDestination.maps);
  });
}
