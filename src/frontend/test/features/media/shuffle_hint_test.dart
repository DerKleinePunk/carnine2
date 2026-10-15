import 'package:carnine_frontend/features/media/domain/models/player_snapshot.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/features/media/presentation/player_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/control_button.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_media_repository.dart';
import '../../fakes/media_test_harness.dart';

/// "Zufall an" and "Titel wiederholen" at once (#143): the player repeats the
/// track, shuffle does nothing. The settings stay as set; the player shows it.
void main() {
  group('PlayerController', () {
    late PlayerController controller;

    setUp(() {
      controller = PlayerController(repository: FakeMediaRepository());
    });

    tearDown(() => controller.dispose());

    test(
      'shuffle alone, or with repeating the queue, does something',
      () async {
        await controller.toggleShuffle();
        expect(controller.shuffleHasNoEffect, isFalse);

        await controller.cycleRepeat();
        expect(controller.repeatMode, MediaRepeatMode.queue);
        expect(controller.shuffleHasNoEffect, isFalse);
        expect(controller.showsModeHint, isFalse);
      },
    );

    test(
      'shuffle on with repeating the track does nothing, in either order',
      () async {
        await controller.toggleShuffle();
        await controller.cycleRepeat();
        await controller.cycleRepeat();
        expect(controller.repeatMode, MediaRepeatMode.track);
        expect(controller.shuffleHasNoEffect, isTrue);

        final other = PlayerController(repository: FakeMediaRepository());
        addTearDown(other.dispose);
        await other.cycleRepeat();
        await other.cycleRepeat();
        expect(other.shuffleHasNoEffect, isFalse, reason: 'shuffle is off');
        await other.toggleShuffle();
        expect(other.shuffleHasNoEffect, isTrue);
      },
    );

    test(
      'the settings are not touched: both stay as the user set them',
      () async {
        await controller.toggleShuffle();
        await controller.cycleRepeat();
        await controller.cycleRepeat();

        expect(controller.shuffleEnabled, isTrue);
        expect(controller.repeatMode, MediaRepeatMode.track);
      },
    );

    test('the note comes with the tap that makes them meet', () async {
      await controller.cycleRepeat();
      await controller.cycleRepeat();
      expect(controller.showsModeHint, isFalse, reason: 'repeat alone');

      await controller.toggleShuffle();
      expect(controller.showsModeHint, isTrue, reason: 'shuffle joins it');
    });

    test('the same when repeat is the tap that makes them meet', () async {
      await controller.toggleShuffle();
      await controller.cycleRepeat();
      expect(controller.showsModeHint, isFalse);

      await controller.cycleRepeat();

      expect(controller.showsModeHint, isTrue);
    });

    test(
      'a tap that ends the combination takes the note away at once',
      () async {
        await controller.toggleShuffle();
        await controller.cycleRepeat();
        await controller.cycleRepeat();
        expect(controller.showsModeHint, isTrue);

        await controller.cycleRepeat();
        expect(controller.showsModeHint, isFalse);

        await controller.cycleRepeat();
        await controller.cycleRepeat();
        expect(controller.showsModeHint, isTrue);
        await controller.toggleShuffle();
        expect(controller.showsModeHint, isFalse);
      },
    );

    test('the note goes by itself after 3 seconds', () {
      fakeAsync((async) {
        final player = PlayerController(repository: FakeMediaRepository());
        player.toggleShuffle();
        player.cycleRepeat();
        player.cycleRepeat();
        async.flushMicrotasks();
        expect(player.showsModeHint, isTrue);

        async.elapse(const Duration(seconds: 2, milliseconds: 900));
        expect(player.showsModeHint, isTrue);

        async.elapse(const Duration(milliseconds: 100));
        expect(player.showsModeHint, isFalse);
        // The icon stays pale: only the note went.
        expect(player.shuffleHasNoEffect, isTrue);
        player.dispose();
      });
    });

    test('a new tap gives the note another 3 seconds', () {
      fakeAsync((async) {
        final player = PlayerController(repository: FakeMediaRepository());
        player.toggleShuffle();
        player.cycleRepeat();
        player.cycleRepeat();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 2));
        // Away and back at once: the combination is met again.
        player.cycleRepeat();
        player.cycleRepeat();
        player.cycleRepeat();
        async.flushMicrotasks();
        expect(player.showsModeHint, isTrue);

        async.elapse(const Duration(seconds: 2, milliseconds: 900));
        expect(player.showsModeHint, isTrue);
        async.elapse(const Duration(milliseconds: 200));
        expect(player.showsModeHint, isFalse);
        player.dispose();
      });
    });
  });

  group('on the player page', () {
    late FakeMediaRepository repository;
    late MediaController controller;

    setUp(() {
      repository = FakeMediaRepository();
      controller = MediaController(
        repository: repository,
        heartbeatInterval: null,
      );
    });

    tearDown(() => controller.dispose());

    const hint = 'TITEL WIRD WIEDERHOLT, ZUFALL OHNE WIRKUNG';

    ControlButton shuffleButton(WidgetTester tester) => tester
        .widgetList<ControlButton>(find.byType(ControlButton))
        .firstWhere((button) => button.icon == Icons.shuffle);

    Color shuffleColor(WidgetTester tester) => tester
        .widget<Icon>(
          find.descendant(
            of: find.byWidget(shuffleButton(tester)),
            matching: find.byIcon(Icons.shuffle),
          ),
        )
        .color!;

    Future<void> open(WidgetTester tester) async {
      setUpMediaView(tester);
      await tester.pumpWidget(mediaHarness(controller));
      await tester.pump();
    }

    testWidgets('shuffle on, repeating the queue: bright, no note', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.byIcon(Icons.shuffle));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();

      expect(shuffleColor(tester), AppColors.primary);
      expect(shuffleButton(tester).isIneffective, isFalse);
      expect(find.text(hint), findsNothing);
    });

    testWidgets('shuffle on, then repeating the track: pale icon and the '
        'note for 3 seconds', (tester) async {
      await open(tester);
      await tester.tap(find.byIcon(Icons.shuffle));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();

      expect(shuffleButton(tester).isIneffective, isTrue);
      expect(shuffleButton(tester).isActive, isTrue, reason: 'still on');
      expect(find.text(hint), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(shuffleColor(tester).a, closeTo(0.45, 0.01));

      await tester.pump(PlayerController.modeHintDuration);
      await tester.pump();
      expect(find.text(hint), findsNothing);
      // The icon stays pale as long as the two meet.
      expect(shuffleButton(tester).isIneffective, isTrue);
    });

    testWidgets('the dot below the pale icon is a ring, not a filled dot', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byIcon(Icons.shuffle));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();

      final dots = tester
          .widgetList<ToggleDot>(find.byType(ToggleDot))
          .toList();
      // Shuffle first, repeat second.
      expect(dots[0].isRing, isTrue);
      expect(dots[1].isRing, isFalse);

      await tester.pump(PlayerController.modeHintDuration);
    });

    testWidgets('repeat turned off again: the icon is bright, the note gone', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byIcon(Icons.shuffle));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();
      expect(find.text(hint), findsOneWidget);

      await tester.tap(find.byIcon(Icons.repeat_one));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(find.text(hint), findsNothing);
      expect(shuffleButton(tester).isIneffective, isFalse);
      expect(shuffleColor(tester), AppColors.primary);
    });

    testWidgets('a screen reader hears why the icon is pale', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester);
      await tester.tap(find.byIcon(Icons.shuffle));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();

      expect(
        tester.getSemantics(find.byIcon(Icons.shuffle)).label,
        'Zufallswiedergabe, Titel wird wiederholt, Zufall ohne Wirkung',
      );
      await tester.pump(PlayerController.modeHintDuration);
      semantics.dispose();
    });

    testWidgets('repeating the track alone leaves the shuffle icon grey', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pump();

      expect(shuffleColor(tester), AppColors.outline);
      expect(find.text(hint), findsNothing);
    });
  });

  group('every language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      test('${locale.languageCode}: the note is a text of its own', () {
        final text = AppLocalizations(
          locale,
        ).text(AppTextKey.mediaShuffleNoEffectHint);

        expect(text, isNotEmpty);
        expect(text, isNot(contains('...')));
        if (locale.languageCode != 'de') {
          expect(
            text,
            isNot(
              AppLocalizations(
                const Locale('de'),
              ).text(AppTextKey.mediaShuffleNoEffectHint),
            ),
          );
        }
      });
    }
  });
}
