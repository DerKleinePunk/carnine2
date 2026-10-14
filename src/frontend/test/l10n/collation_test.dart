import 'dart:ui';

import 'package:carnine_frontend/l10n/app_language_option.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/l10n/collation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('collationKey (#92)', () {
    test('case does not matter', () {
      expect(collationKey('Deutsch'), collationKey('DEUTSCH'));
    });

    test('umlauts sort with their plain letter', () {
      expect(collationKey('Dänisch'), 'danisch');
      expect(collationKey('Türkisch'), 'turkisch');
      expect(collationKey('Östra'), 'ostra');
      expect(
        collationKey('Dänisch').compareTo(collationKey('Deutsch')),
        lessThan(0),
      );
    });

    test('ß and ligatures spell out', () {
      expect(collationKey('Straße'), 'strasse');
      expect(collationKey('Æble'), 'aeble');
      expect(collationKey('Œuf'), 'oeuf');
    });

    test('the letters of the other languages sort with the plain ones', () {
      expect(collationKey('Polski ń ł ź ż ś ć ą ę'), 'polski n l z z s c a e');
      expect(
        collationKey('Čeština ř š ž ě ů ď ť ň'),
        'cestina r s z e u d t n',
      );
      expect(collationKey('Magyar ő ű'), 'magyar o u');
      expect(collationKey('Türkçe ş ğ ı'), 'turkce s g i');
    });

    test('a Turkish capital İ loses its dot', () {
      expect(collationKey('İngilizce'), 'ingilizce');
    });

    test('letters outside the table stay as they are', () {
      expect(collationKey('日本語'), '日本語');
      expect(collationKey('中文'), '中文');
    });
  });

  group('the language list (#92)', () {
    List<String> names(Locale locale) {
      final l10n = AppLocalizations(locale);
      return [
        for (final option in sortedLanguageOptions(l10n))
          l10n.text(option.labelKey),
      ];
    }

    test('in German "Dänisch" is before "Deutsch", as the guide says', () {
      expect(names(const Locale('de')), [
        'Chinesisch',
        'Dänisch',
        'Deutsch',
        'Englisch',
        'Französisch',
        'Italienisch',
        'Japanisch',
        'Niederländisch',
        'Polnisch',
        'Portugiesisch',
        'Schwedisch',
        'Spanisch',
        'Tschechisch',
        'Türkisch',
        'Ungarisch',
      ]);
    });

    test('in every display language all 15 languages come, in order of their '
        'sort key', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = AppLocalizations(locale);
        final sorted = sortedLanguageOptions(l10n);

        expect(sorted, hasLength(15), reason: locale.languageCode);
        expect(
          sorted.map((option) => option.locale.languageCode).toSet(),
          hasLength(15),
          reason: '${locale.languageCode}: each language once',
        );
        final keys = [
          for (final option in sorted) collationKey(l10n.text(option.labelKey)),
        ];
        for (var i = 1; i < keys.length; i++) {
          expect(
            keys[i - 1].compareTo(keys[i]),
            lessThanOrEqualTo(0),
            reason: '${locale.languageCode}: ${keys[i - 1]} before ${keys[i]}',
          );
        }
      }
    });
  });

  group('the subtitle of the page Geräte (#92)', () {
    test('in German it names the five rows, with their titles', () {
      final l10n = AppLocalizations(const Locale('de'));
      final subtitle = l10n.text(AppTextKey.settingsDevicesSubtitle);

      expect(
        subtitle,
        'Kamera, Display, Audio-Ausgang, Handy-App und Netzteil',
      );
      for (final title in [
        AppTextKey.settingsDevicesCameraTitle,
        AppTextKey.settingsDevicesDisplayTitle,
        AppTextKey.settingsDevicesAudioTitle,
        AppTextKey.settingsDevicesPhoneTitle,
        AppTextKey.settingsDevicesPowerTitle,
      ]) {
        expect(subtitle, contains(l10n.text(title)));
      }
    });

    test('in every language it is a text with five parts', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final subtitle = AppLocalizations(
          locale,
        ).text(AppTextKey.settingsDevicesSubtitle);

        // Separators for five parts, written the way the language does.
        final separators = RegExp('[,、]|和|と').allMatches(subtitle).length;
        expect(
          separators,
          greaterThanOrEqualTo(2),
          reason: locale.languageCode,
        );
        expect(subtitle, isNot(contains('...')), reason: locale.languageCode);
      }
    });
  });
}
