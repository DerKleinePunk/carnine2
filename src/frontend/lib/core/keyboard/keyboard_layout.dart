/// Which set of character rows [KeyboardLayouts] currently renders.
enum KeyboardLayer { letters, numbersSymbols }

/// A single key on the on-screen keyboard grid.
///
/// [flex] mirrors [Expanded.flex] - it controls a key's relative width
/// within its row so wider keys (backspace, shift, space, done) don't need
/// a separate layout mechanism.
sealed class KeyboardEntry {
  const KeyboardEntry({this.flex = 1});

  final int flex;
}

/// A literal, insertable character. [diacritics], when present, are offered
/// via long-press in addition to the plain [base] character reachable via a
/// normal tap.
class CharacterKey extends KeyboardEntry {
  const CharacterKey(this.base, {this.diacritics, super.flex = 1});

  final String base;
  final List<String>? diacritics;

  bool get hasDiacritics => diacritics != null && diacritics!.isNotEmpty;
}

/// Deletes one grapheme before the cursor, or the current selection.
class BackspaceKey extends KeyboardEntry {
  const BackspaceKey({super.flex = 2});
}

/// One-shot capitalization of the next inserted character.
class ShiftKey extends KeyboardEntry {
  const ShiftKey({super.flex = 2});
}

/// Switches between [KeyboardLayer.letters] and [KeyboardLayer.numbersSymbols].
class LayerToggleKey extends KeyboardEntry {
  const LayerToggleKey({super.flex = 2});
}

/// Inserts a single space.
class SpaceKey extends KeyboardEntry {
  const SpaceKey({super.flex = 6});
}

/// Closes the keyboard and reports the current text as submitted.
class DoneKey extends KeyboardEntry {
  const DoneKey({super.flex = 3});
}

/// The on-screen keyboard's key rows.
///
/// One shared layout serves every supported locale (including zh/ja, which
/// use it for raw Pinyin/Romaji entry until a dedicated IME ticket lands) -
/// per-locale variation is expressed only through which diacritics a key
/// offers on long-press, never through a different physical layout.
abstract final class KeyboardLayouts {
  const KeyboardLayouts._();

  static const List<List<KeyboardEntry>> letters = <List<KeyboardEntry>>[
    <KeyboardEntry>[
      CharacterKey('q'),
      CharacterKey('w'),
      CharacterKey('e', diacritics: ['è', 'é', 'ê', 'ë', 'ě', 'ę']),
      CharacterKey('r', diacritics: ['ř']),
      CharacterKey('t', diacritics: ['ť']),
      CharacterKey('y', diacritics: ['ý']),
      CharacterKey('u', diacritics: ['ù', 'ú', 'û', 'ü', 'ů', 'ű']),
      CharacterKey('i', diacritics: ['ì', 'í', 'î', 'ï', 'ı']),
      CharacterKey('o', diacritics: ['ò', 'ó', 'ô', 'ö', 'õ', 'ø', 'ő']),
      CharacterKey('p'),
      BackspaceKey(),
    ],
    <KeyboardEntry>[
      CharacterKey('a', diacritics: ['à', 'á', 'â', 'ä', 'ã', 'å', 'æ', 'ą']),
      CharacterKey('s', diacritics: ['ß', 'ś', 'š', 'ş']),
      CharacterKey('d', diacritics: ['ď']),
      CharacterKey('f'),
      CharacterKey('g', diacritics: ['ğ']),
      CharacterKey('h'),
      CharacterKey('j'),
      CharacterKey('k'),
      CharacterKey('l', diacritics: ['ł']),
    ],
    <KeyboardEntry>[
      ShiftKey(),
      CharacterKey('z', diacritics: ['ź', 'ż', 'ž']),
      CharacterKey('x'),
      CharacterKey('c', diacritics: ['ç', 'ć', 'č']),
      CharacterKey('v'),
      CharacterKey('b'),
      CharacterKey('n', diacritics: ['ñ', 'ń', 'ň']),
      CharacterKey('m'),
    ],
  ];

  static const List<List<KeyboardEntry>> numbersSymbols = <List<KeyboardEntry>>[
    <KeyboardEntry>[
      CharacterKey('1'),
      CharacterKey('2'),
      CharacterKey('3'),
      CharacterKey('4'),
      CharacterKey('5'),
      CharacterKey('6'),
      CharacterKey('7'),
      CharacterKey('8'),
      CharacterKey('9'),
      CharacterKey('0'),
      BackspaceKey(),
    ],
    <KeyboardEntry>[
      CharacterKey('@'),
      CharacterKey('#'),
      CharacterKey(r'$'),
      CharacterKey('_'),
      CharacterKey('&'),
      CharacterKey('-'),
      CharacterKey('+'),
      CharacterKey('('),
      CharacterKey(')'),
      CharacterKey('/'),
    ],
    <KeyboardEntry>[
      CharacterKey('*'),
      CharacterKey('"'),
      CharacterKey("'"),
      CharacterKey(':'),
      CharacterKey(';'),
      CharacterKey('!'),
      CharacterKey('?'),
    ],
  ];

  /// Shared between both layers so the row a thumb rests on never moves.
  static const List<KeyboardEntry> bottomRow = <KeyboardEntry>[
    LayerToggleKey(),
    CharacterKey(','),
    SpaceKey(),
    CharacterKey('.'),
    DoneKey(),
  ];
}
