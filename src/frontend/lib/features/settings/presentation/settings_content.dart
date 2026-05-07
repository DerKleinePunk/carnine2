import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_language_option.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/language_flag.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Settings mockup with global frontend language controls.
class SettingsContent extends StatelessWidget {
  const SettingsContent({
    required this.languageController,
    super.key,
  });

  final AppLanguageController languageController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: languageController,
      builder: (context, child) {
        final l10n = AppLocalizations.of(context);

        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: SizedBox(
              width: 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.text(AppTextKey.settingsTitle),
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.text(AppTextKey.settingsMockDescription),
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _LanguageSection(languageController: languageController),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LanguageSection extends StatelessWidget {
  const _LanguageSection({required this.languageController});

  final AppLanguageController languageController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: AppColors.primary20, blurRadius: 18),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.text(AppTextKey.settingsLanguageTitle),
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.text(AppTextKey.settingsLanguageSubtitle),
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            _LanguageDropdown(languageController: languageController),
          ],
        ),
      ),
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({required this.languageController});

  final AppLanguageController languageController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      width: 360,
      child: DropdownButtonFormField<Locale>(
        key: ValueKey<String>(languageController.locale.languageCode),
        initialValue: languageController.locale,
        isExpanded: true,
        dropdownColor: AppColors.surfaceContainerHigh,
        iconEnabledColor: AppColors.primary,
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          enabledBorder: _border(AppColors.primary20),
          focusedBorder: _border(AppColors.primary),
          border: _border(AppColors.primary20),
        ),
        items: [
          for (final option in AppLanguageOptions.all)
            DropdownMenuItem<Locale>(
              value: option.locale,
              child: _LanguageOptionRow(option: option, l10n: l10n),
            ),
        ],
        selectedItemBuilder: (context) {
          return [
            for (final option in AppLanguageOptions.all)
              _LanguageOptionRow(option: option, l10n: l10n),
          ];
        },
        onChanged: (locale) {
          if (locale == null) {
            return;
          }

          languageController.setLocale(locale);
        },
      ),
    );
  }

  OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );
  }
}

class _LanguageOptionRow extends StatelessWidget {
  const _LanguageOptionRow({
    required this.option,
    required this.l10n,
  });

  final AppLanguageOption option;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        LanguageFlag(flag: option.flag),
        const SizedBox(width: 12),
        Text(
          l10n.text(option.labelKey),
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
