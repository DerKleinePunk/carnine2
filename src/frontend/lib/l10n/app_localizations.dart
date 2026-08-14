import 'package:flutter/material.dart';

import 'app_text_key.dart';
import 'translations/cs.dart';
import 'translations/da.dart';
import 'translations/de.dart';
import 'translations/en.dart';
import 'translations/es.dart';
import 'translations/fr.dart';
import 'translations/hu.dart';
import 'translations/it.dart';
import 'translations/ja.dart';
import 'translations/nl.dart';
import 'translations/pl.dart';
import 'translations/pt.dart';
import 'translations/sv.dart';
import 'translations/tr.dart';
import 'translations/zh.dart';

export 'app_text_key.dart';

/// App-localized strings for all supported frontend languages.
///
/// Adding a visible string: introduce a key in [AppTextKey]
/// (`lib/l10n/app_text_key.dart`), add its value for every locale in
/// `lib/l10n/translations/`, then consume it through [AppLocalizations.text].
class AppLocalizations {
  const AppLocalizations(this.locale);

  static const Locale defaultLocale = Locale('de');
  static const Locale fallbackLocale = Locale('en');
  static const List<Locale> supportedLocales = <Locale>[
    defaultLocale,
    fallbackLocale,
    Locale('fr'),
    Locale('es'),
    Locale('it'),
    Locale('zh'),
    Locale('ja'),
    Locale('nl'),
    Locale('pl'),
    Locale('hu'),
    Locale('tr'),
    Locale('pt'),
    Locale('cs'),
    Locale('sv'),
    Locale('da'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  final Locale locale;

  static const Map<String, Map<AppTextKey, String>> _values =
      <String, Map<AppTextKey, String>>{
    'de': deTranslations,
    'en': enTranslations,
    'fr': frTranslations,
    'es': esTranslations,
    'it': itTranslations,
    'zh': zhTranslations,
    'ja': jaTranslations,
    'nl': nlTranslations,
    'pl': plTranslations,
    'hu': huTranslations,
    'tr': trTranslations,
    'pt': ptTranslations,
    'cs': csTranslations,
    'sv': svTranslations,
    'da': daTranslations,
  };

  static AppLocalizations of(BuildContext context) {
    final localizations =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (localizations == null) {
      throw StateError('AppLocalizations is not available in this context.');
    }

    return localizations;
  }

  /// Resolves a translated string and falls back to English for missing keys.
  String text(AppTextKey key) {
    final languageValues = _values[locale.languageCode];
    final fallbackValues = _values[fallbackLocale.languageCode];

    return languageValues?[key] ?? fallbackValues?[key] ?? key.name;
  }

  String dashboardContentFor(String section) {
    return text(AppTextKey.dashboardContentFor)
        .replaceFirst('{section}', section);
  }

  String grpcStatus(String status) {
    return text(AppTextKey.grpcStatus).replaceFirst('{status}', status);
  }

  String statusConnected(int count) {
    return text(AppTextKey.statusConnected)
        .replaceFirst('{count}', count.toString());
  }

  String mediaAlbumLine({required String album, required int year}) {
    return text(AppTextKey.mediaAlbumLabel)
        .replaceFirst('{album}', album)
        .replaceFirst('{year}', year.toString());
  }

  String canDataLine({
    required String sensor,
    required double value,
    required Object timestamp,
  }) {
    return text(AppTextKey.canDataLine)
        .replaceFirst('{sensor}', sensor)
        .replaceFirst('{value}', value.toString())
        .replaceFirst('{time}', timestamp.toString());
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final selectedLocale = isSupported(locale)
        ? Locale(locale.languageCode)
        : AppLocalizations.fallbackLocale;

    return AppLocalizations(selectedLocale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
