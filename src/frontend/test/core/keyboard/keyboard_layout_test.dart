import 'package:carnine_frontend/core/keyboard/keyboard_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KeyboardLayouts', () {
    test('letters covers every base a-z exactly once', () {
      final bases = KeyboardLayouts.letters
          .expand((row) => row)
          .whereType<CharacterKey>()
          .map((key) => key.base)
          .toList();

      expect(bases.toSet(),
          unorderedEquals('abcdefghijklmnopqrstuvwxyz'.split('')));
      expect(bases, hasLength(26));
    });

    test('numbersSymbols has no diacritic keys', () {
      final withDiacritics = KeyboardLayouts.numbersSymbols
          .expand((row) => row)
          .whereType<CharacterKey>()
          .where((key) => key.hasDiacritics);

      expect(withDiacritics, isEmpty);
    });

    test(
        'bottom row is shared by both layers and carries exactly one '
        'each of layer-toggle, space and done', () {
      final entries = KeyboardLayouts.bottomRow;

      expect(entries.whereType<LayerToggleKey>(), hasLength(1));
      expect(entries.whereType<SpaceKey>(), hasLength(1));
      expect(entries.whereType<DoneKey>(), hasLength(1));
    });

    test('diacritics tables cover the locales the ticket promised', () {
      final diacriticsByBase = {
        for (final key in KeyboardLayouts.letters
            .expand((row) => row)
            .whereType<CharacterKey>()
            .where((key) => key.hasDiacritics))
          key.base: key.diacritics!,
      };

      // Polish needs ą ę ć ł ń ó ś ź ż.
      expect(diacriticsByBase['o'], contains('ó'));
      expect(diacriticsByBase['c'], contains('ć'));
      expect(diacriticsByBase['l'], contains('ł'));
      expect(diacriticsByBase['n'], contains('ń'));
      expect(diacriticsByBase['s'], contains('ś'));
      expect(diacriticsByBase['z'], containsAll(['ź', 'ż']));

      // Turkish needs ç ğ ı ö ş ü.
      expect(diacriticsByBase['c'], contains('ç'));
      expect(diacriticsByBase['g'], contains('ğ'));
      expect(diacriticsByBase['i'], contains('ı'));
      expect(diacriticsByBase['o'], contains('ö'));
      expect(diacriticsByBase['s'], contains('ş'));
      expect(diacriticsByBase['u'], contains('ü'));

      // Polish also needs the ogonek vowels ą and ę.
      expect(diacriticsByBase['a'], contains('ą'));
      expect(diacriticsByBase['e'], contains('ę'));
    });
  });
}
