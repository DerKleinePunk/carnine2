import 'dart:async';

import 'package:carnine_frontend/features/dashboard/data/thermal_status_source.dart';
import 'package:carnine_frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/dashboard_screen.dart';
import 'package:carnine_frontend/features/dashboard/presentation/thermal_warning_controller.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart' as pb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_media_repository.dart';

class _FakeSource implements ThermalStatusSource {
  final StreamController<ThermalStatus> controller =
      StreamController<ThermalStatus>.broadcast();

  @override
  Stream<ThermalStatus> get statuses => controller.stream;

  @override
  Future<void> dispose() => controller.close();
}

const _hot = ThermalStatus(overheated: true, cpuCelsius: 76.5);
const _cool = ThermalStatus(overheated: false, cpuCelsius: 69.0);

void main() {
  test('the proto status maps with and without a reading', () {
    final hot = thermalStatusFromProto(
      pb.ThermalStatus(overheated: true, cpuTemperatureCelsius: 76.5),
    );
    expect(hot.overheated, isTrue);
    expect(hot.cpuCelsius, 76.5);

    final none = thermalStatusFromProto(pb.ThermalStatus());
    expect(none.overheated, isFalse);
    expect(none.cpuCelsius, isNull);
  });

  group('ThermalWarningController', () {
    late _FakeSource source;
    late ThermalWarningController controller;

    setUp(() {
      source = _FakeSource();
      controller = ThermalWarningController(source: source)..start();
    });

    tearDown(() => controller.dispose());

    Future<void> send(ThermalStatus status) async {
      source.controller.add(status);
      await Future<void>.delayed(Duration.zero);
    }

    test('shows the warning once overheated, until confirmed', () async {
      expect(controller.showsWarning, isFalse);

      await send(_hot);
      expect(controller.showsWarning, isTrue);
      expect(controller.status.cpuCelsius, 76.5);

      controller.confirm();
      expect(controller.showsWarning, isFalse);
    });

    test('a confirmed warning stays away while the CPU is still hot', () async {
      await send(_hot);
      controller.confirm();

      // A reconnect reports the same status again.
      await send(_hot);

      expect(controller.showsWarning, isFalse);
    });

    test('the warning comes back after cooling down and heating up', () async {
      await send(_hot);
      controller.confirm();
      await send(_cool);
      expect(controller.showsWarning, isFalse);

      await send(_hot);

      expect(controller.showsWarning, isTrue);
    });

    test('an unconfirmed warning goes once the CPU cooled down', () async {
      await send(_hot);
      await send(_cool);

      expect(controller.showsWarning, isFalse);
    });
  });

  test('every language has the warning texts', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = AppLocalizations(locale);
      for (final key in [
        AppTextKey.thermalWarningTitle,
        AppTextKey.thermalWarningMessage,
        AppTextKey.thermalWarningConfirm,
      ]) {
        expect(
          l10n.hasOwnText(key),
          isTrue,
          reason: '${locale.languageCode} lacks ${key.name}',
        );
      }
      expect(
        l10n.text(AppTextKey.thermalWarningMessage),
        contains('{temperature}'),
        reason: locale.languageCode,
      );
    }
  });

  test('the temperature is shown in the notation of the language', () {
    expect(
      AppLocalizations(const Locale('de')).thermalWarningMessage(76.5),
      contains('76,5 °C'),
    );
    expect(
      AppLocalizations(const Locale('en')).thermalWarningMessage(76.5),
      contains('76.5 °C'),
    );
  });

  group('on the dashboard', () {
    late _FakeSource source;
    late ThermalWarningController thermal;
    late DashboardController dashboard;
    late MediaController media;

    setUp(() {
      source = _FakeSource();
      thermal = ThermalWarningController(source: source);
      dashboard = DashboardController();
      media = MediaController(
        repository: FakeMediaRepository(),
        heartbeatInterval: null,
      );
    });

    tearDown(() {
      thermal.dispose();
      dashboard.dispose();
      media.dispose();
    });

    /// The status reaches the controller in a microtask during the first
    /// pump; the rebuild it causes is the next frame.
    Future<void> sendHot(WidgetTester tester) async {
      source.controller.add(_hot);
      await tester.pump();
      await tester.pump();
    }

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
            thermalWarningController: thermal,
          ),
        ),
      );
      await tester.pump();
    }

    for (final page in [0, 2]) {
      testWidgets('the warning comes up over page $page and goes on OK', (
        tester,
      ) async {
        await pumpDashboard(tester);
        dashboard.selectItem(page);
        await tester.pump();
        expect(find.text('Gerät überhitzt'), findsNothing);

        await sendHot(tester);

        expect(find.text('Gerät überhitzt'), findsOneWidget);
        expect(find.textContaining('76,5 °C'), findsOneWidget);

        await tester.tap(find.text('Verstanden'));
        await tester.pump();

        expect(find.text('Gerät überhitzt'), findsNothing);
        expect(dashboard.selectedIndex, page);
      });
    }

    testWidgets('the page below cannot be used while the warning is up', (
      tester,
    ) async {
      await pumpDashboard(tester);
      await sendHot(tester);

      // The maps entry of the side menu, below the barrier.
      await tester.tap(find.text('Karten'), warnIfMissed: false);
      await tester.pump();

      expect(dashboard.selectedIndex, 0);
      expect(find.text('Gerät überhitzt'), findsOneWidget);
    });
  });
}
