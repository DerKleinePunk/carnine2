import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Shared Material theme for the automotive display.
///
/// Colors and typography are centralized here to keep widgets free from hard
/// coded visual tokens and aligned with the Stitch design source.
abstract final class CarnineTheme {
  const CarnineTheme._();

  static ThemeData get dark {
    return ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: _darkColorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: const TextTheme(
        headlineLarge: AppTextStyles.headlineLarge,
        bodyLarge: AppTextStyles.bodyLarge,
        labelLarge: AppTextStyles.labelLarge,
      ),
    );
  }

  static const ColorScheme _darkColorScheme = ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    error: AppColors.error,
    onError: AppColors.onError,
  );
}
