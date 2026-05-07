import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Selectable frontend language with display metadata for the settings UI.
class AppLanguageOption {
  const AppLanguageOption({
    required this.locale,
    required this.labelKey,
    required this.flag,
  });

  final Locale locale;
  final AppTextKey labelKey;
  final AppLanguageFlag flag;
}

enum AppLanguageFlag {
  germany,
  unitedKingdom,
  france,
  spain,
  italy,
  china,
  japan,
}

/// All languages currently selectable by the frontend.
abstract final class AppLanguageOptions {
  const AppLanguageOptions._();

  static const List<AppLanguageOption> all = <AppLanguageOption>[
    AppLanguageOption(
      locale: Locale('de'),
      labelKey: AppTextKey.languageGerman,
      flag: AppLanguageFlag.germany,
    ),
    AppLanguageOption(
      locale: Locale('en'),
      labelKey: AppTextKey.languageEnglish,
      flag: AppLanguageFlag.unitedKingdom,
    ),
    AppLanguageOption(
      locale: Locale('fr'),
      labelKey: AppTextKey.languageFrench,
      flag: AppLanguageFlag.france,
    ),
    AppLanguageOption(
      locale: Locale('es'),
      labelKey: AppTextKey.languageSpanish,
      flag: AppLanguageFlag.spain,
    ),
    AppLanguageOption(
      locale: Locale('it'),
      labelKey: AppTextKey.languageItalian,
      flag: AppLanguageFlag.italy,
    ),
    AppLanguageOption(
      locale: Locale('zh'),
      labelKey: AppTextKey.languageChinese,
      flag: AppLanguageFlag.china,
    ),
    AppLanguageOption(
      locale: Locale('ja'),
      labelKey: AppTextKey.languageJapanese,
      flag: AppLanguageFlag.japan,
    ),
  ];

  static AppLanguageOption byLocale(Locale locale) {
    return all.firstWhere(
      (option) => option.locale.languageCode == locale.languageCode,
      orElse: () => all.first,
    );
  }
}
