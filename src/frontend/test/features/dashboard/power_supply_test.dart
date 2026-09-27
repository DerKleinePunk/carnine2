import 'dart:async';

import 'package:carnine_frontend/features/dashboard/data/power_supply_source.dart';
import 'package:carnine_frontend/features/dashboard/presentation/power_supply_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/carnine_top_bar.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart' as pb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSource implements PowerSupplySource {
  final StreamController<PowerSupplyStatus> controller =
      StreamController<PowerSupplyStatus>.broadcast();

  @override
  Stream<PowerSupplyStatus> get statuses => controller.stream;

  @override
  Future<void> dispose() => controller.close();
}

Widget _harness(PowerSupplyStatus status) {
  return MaterialApp(
    locale: const Locale('de'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: Column(
        children: [
          CarnineTopBar(powerSupply: status),
          PowerSupplyNotice(status: status),
        ],
      ),
    ),
  );
}

const _running = PowerSupplyStatus(
  configured: true,
  connected: true,
  ignition: true,
  state: PowerSupplyState.run,
  inputVolts: 13.4,
);

void main() {
  test('an unconfigured supply maps to none, a running one field by field', () {
    expect(
      powerSupplyStatusFromProto(pb.PowerSupplyStatus()).configured,
      isFalse,
    );
    final status = powerSupplyStatusFromProto(
      pb.PowerSupplyStatus(
        configured: true,
        connected: true,
        ignition: false,
        state: pb.PowerSupplyState.POWER_SUPPLY_STATE_POWER_OFF,
        inputVoltageVolts: 12.1,
      ),
    );
    expect(status.ignition, isFalse);
    expect(status.state, PowerSupplyState.powerOff);
    expect(status.inputVolts, 12.1);
    expect(status.switchingOff, isTrue);

    final unknown = powerSupplyStatusFromProto(
      pb.PowerSupplyStatus(configured: true, connected: true),
    );
    expect(unknown.ignition, isNull);
    expect(unknown.inputVolts, isNull);
    expect(unknown.switchingOff, isFalse);
  });

  test('the controller follows the source', () async {
    final source = _FakeSource();
    final controller = PowerSupplyController(source: source)..start();
    addTearDown(controller.dispose);
    expect(controller.status.configured, isFalse);

    source.controller.add(_running);
    await Future<void>.delayed(Duration.zero);
    expect(controller.status.inputVolts, 13.4);
  });

  testWidgets('without a supply the top bar shows nothing of it', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(PowerSupplyStatus.none));
    await tester.pump();
    expect(find.byType(PowerSupplyIndicator), findsNothing);
    expect(find.text('Netzteil schaltet ab'), findsNothing);
  });

  testWidgets('a running supply shows the voltage and no notice', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_running));
    await tester.pump();
    expect(find.text('13,4 V'), findsOneWidget);
    expect(find.textContaining('Zündung aus'), findsNothing);
  });

  testWidgets('ignition off brings the notice', (tester) async {
    await tester.pumpWidget(
      _harness(
        const PowerSupplyStatus(
          configured: true,
          connected: true,
          ignition: false,
          state: PowerSupplyState.powerOff,
          inputVolts: 12.9,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Zündung aus – das Netzteil schaltet ab'), findsOneWidget);
    expect(find.byIcon(Icons.key_off), findsOneWidget);
  });

  testWidgets('a silent supply shows as not responding, without a notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(const PowerSupplyStatus(configured: true, connected: false)),
    );
    await tester.pump();
    expect(find.byIcon(Icons.power_off), findsOneWidget);
    expect(find.bySemanticsLabel('Netzteil antwortet nicht'), findsOneWidget);
    expect(find.byType(PowerSupplyNotice), findsOneWidget);
    expect(find.textContaining('schaltet ab'), findsNothing);
  });
}
