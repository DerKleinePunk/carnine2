import 'package:carnine_frontend/features/media/presentation/audio_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/volume_control.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_media_repository.dart';

/// The row on its own, with nothing around it that rebuilds - as in the
/// player while nothing plays (#176).
Widget _harness(AudioController controller) {
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
      body: Center(
        child: SizedBox(
          width: 400,
          child: VolumeControl(controller: controller),
        ),
      ),
    ),
  );
}

void main() {
  late FakeMediaRepository repository;
  late AudioController controller;

  setUp(() {
    repository = FakeMediaRepository()..volumePercent = 50;
    controller = AudioController(repository: repository);
  });

  tearDown(() => controller.dispose());

  double sliderValue(WidgetTester tester) =>
      tester.widget<Slider>(find.byType(Slider)).value;

  testWidgets('dragging without playback moves the slider and stays there', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(controller));
    await controller.setVolume(50);
    await tester.pumpAndSettle();
    expect(sliderValue(tester), 50);

    await tester.drag(find.byType(Slider), const Offset(-120, 0));
    await tester.pumpAndSettle();

    final dragged = controller.volumePercent;
    expect(dragged, lessThan(50));
    expect(repository.volumePercent, dragged, reason: 'sent to the backend');
    expect(sliderValue(tester), dragged.toDouble());
    expect(find.text('$dragged%'), findsOneWidget);
  });

  testWidgets('a change of the controller shows at once', (tester) async {
    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();

    await controller.setVolume(30);
    await tester.pumpAndSettle();

    expect(sliderValue(tester), 30);
    expect(find.text('30%'), findsOneWidget);
  });

  testWidgets('muting shows the muted symbol and 0, and back again', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(controller));
    await controller.setVolume(40);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
    expect(sliderValue(tester), 0);

    await tester.tap(find.byIcon(Icons.volume_off));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(sliderValue(tester), 40);
  });
}
