import 'package:flutter/material.dart';

class AppTextStyles {
  static const List<String> fontFamilyFallback = <String>[
    'NotoSansSC',
    'NotoSansJP',
    'Segoe UI',
    'Microsoft YaHei',
    'SimSun',
    'Yu Gothic UI',
    'Meiryo',
    'Noto Sans CJK SC',
    'Noto Sans CJK JP',
    'Noto Sans SC',
    'Noto Sans JP',
    'PingFang SC',
    'Hiragino Sans',
    'Source Han Sans SC',
    'Source Han Sans JP',
    'Arial Unicode MS',
  ];

  // Headline Styles
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontFamilyFallback: fontFamilyFallback,
    fontWeight: FontWeight.w600,
    fontSize: 32,
  );

  // Body Styles
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Manrope',
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16,
  );

  // Label Styles
  static const TextStyle labelLarge = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
  );

  // Custom Styles for UI Components
  static TextStyle kineticBrand = const TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    shadows: [Shadow(color: Color(0x6681ECFF), blurRadius: 8)],
  );

  static TextStyle kineticSubtitle = const TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 8,
    letterSpacing: 2,
  );

  static TextStyle navItem = const TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 10,
    fontWeight: FontWeight.bold,
  );

  static TextStyle appBarTitle = const TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.bold,
    shadows: [Shadow(color: Color(0x6681ECFF), blurRadius: 8)],
  );

  static TextStyle emergencyButton = const TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 9,
    fontWeight: FontWeight.w900,
  );

  static TextStyle logLine = const TextStyle(
    fontFamily: 'Manrope',
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
  );
}
