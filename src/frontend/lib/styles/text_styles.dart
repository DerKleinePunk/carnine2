import 'package:flutter/material.dart';

class AppTextStyles {
  // Headline Styles
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontWeight: FontWeight.w600,
    fontSize: 32,
  );

  // Body Styles
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 16,
  );

  // Label Styles
  static const TextStyle labelLarge = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 14,
  );

  // Custom Styles for UI Components
  static TextStyle kineticBrand = const TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 20,
    fontWeight: FontWeight.bold,
    shadows: [Shadow(color: Color(0x6681ECFF), blurRadius: 8)],
  );

  static TextStyle kineticSubtitle = const TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 8,
    letterSpacing: 2,
  );

  static TextStyle navItem = const TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 10,
    fontWeight: FontWeight.bold,
  );

  static TextStyle appBarTitle = const TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 12,
    fontWeight: FontWeight.bold,
    shadows: [Shadow(color: Color(0x6681ECFF), blurRadius: 8)],
  );

  static TextStyle emergencyButton = const TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w900,
  );

  static TextStyle logLine = const TextStyle(
    fontFamily: 'Manrope',
    fontSize: 12,
  );
}
