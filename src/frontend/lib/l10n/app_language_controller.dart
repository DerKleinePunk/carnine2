import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

/// Holds the active frontend language and notifies the app when it changes.
class AppLanguageController extends ChangeNotifier {
  AppLanguageController({
    Locale initialLocale = AppLocalizations.defaultLocale,
    Logger? logger,
  })  : _locale = _normalize(initialLocale),
        _logger = logger ?? Logger('AppLanguageController');

  final Logger _logger;
  Locale _locale;

  Locale get locale => _locale;

  /// Updates the active locale if the language is supported.
  void setLocale(Locale locale) {
    final nextLocale = _normalize(locale);
    if (_locale == nextLocale) {
      return;
    }

    _logger.info(
      'Switching frontend language from ${_locale.languageCode} '
      'to ${nextLocale.languageCode}',
    );

    _locale = nextLocale;
    notifyListeners();
  }

  static Locale _normalize(Locale locale) {
    final isSupported = AppLocalizations.supportedLocales.any(
      (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
    );

    if (!isSupported) {
      return AppLocalizations.fallbackLocale;
    }

    return Locale(locale.languageCode);
  }
}
