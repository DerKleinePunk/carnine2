/// A key to sort names of any of the app's languages the way people expect:
/// without regard to case, and with the letters of a language beside the
/// plain ones ("ä" with "a", "ß" with "ss"), not behind "z" as the code point
/// order has them (#92).
String collationKey(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final replacement = _replacements[rune];
    buffer.write(replacement ?? String.fromCharCode(rune));
  }
  return buffer.toString();
}

final Map<int, String> _replacements = _build();

Map<int, String> _build() {
  const groups = <String, String>{
    'a': 'àáâãäåāăą',
    'ae': 'æ',
    'c': 'çćĉč',
    'd': 'ďđ',
    'e': 'èéêëēėęě',
    'g': 'ğ',
    'i': 'ìíîïīı',
    'l': 'ł',
    'n': 'ñńň',
    'o': 'òóôõöøōő',
    'oe': 'œ',
    'r': 'ř',
    's': 'śšş',
    'ss': 'ß',
    't': 'ťţ',
    'u': 'ùúûüūůű',
    'y': 'ýÿ',
    'z': 'źżž',
    // The dot a lower-cased Turkish "İ" leaves behind.
    '': '̇',
  };
  return {
    for (final entry in groups.entries)
      for (final rune in entry.value.runes) rune: entry.key,
  };
}
