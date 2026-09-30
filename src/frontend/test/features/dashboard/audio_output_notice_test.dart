import 'package:carnine_frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/dashboard_screen.dart';
import 'package:carnine_frontend/features/media/domain/models/audio_event.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_media_repository.dart';

const _notice =
    'Kein Audio-Ausgang – bitte den Tonausgang prüfen (HDMI oder Klinke)';

void main() {
  late FakeMediaRepository repository;
  late MediaController media;
  late DashboardController dashboard;

  setUp(() {
    repository = FakeMediaRepository();
    media = MediaController(repository: repository, heartbeatInterval: null);
    dashboard = DashboardController();
  });

  tearDown(() {
    media.dispose();
    dashboard.dispose();
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
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
        home: DashboardScreen(
          languageController: AppLanguageController(),
          controller: dashboard,
          mediaController: media,
        ),
      ),
    );
    await tester.pump();
  }

  /// The event reaches the controller in a microtask during the first pump;
  /// the rebuild it causes is the next frame.
  Future<void> send(WidgetTester tester, AudioEventKind kind) async {
    repository.audioEventsController.add(AudioEvent(kind: kind, message: ''));
    await tester.pump();
    await tester.pump();
  }

  // Page 0 is not the media page: the notice must not wait until someone
  // opens it.
  testWidgets('the notice shows on a page other than media and goes again', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(dashboard.selectedIndex, 0);
    expect(find.text(_notice), findsNothing);

    await send(tester, AudioEventKind.outputUnavailable);
    expect(find.text(_notice), findsOneWidget);

    dashboard.selectItem(3);
    await tester.pump();
    expect(find.text(_notice), findsOneWidget);

    await send(tester, AudioEventKind.outputAvailable);
    expect(find.text(_notice), findsNothing);
  });
}
