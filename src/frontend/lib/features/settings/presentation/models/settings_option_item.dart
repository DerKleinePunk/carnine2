import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

enum SettingsSection {
  /// "Darstellung & Sprache": two tabs, the language choice among them.
  appearance,

  /// "Geräte": camera, audio output, phone app, power supply.
  devices,
  diagnostics,
  maps,
}

/// A page below a settings section, reached from one of its rows.
enum SettingsDevicePage {
  /// "Geräte" > "Kamera" (#79).
  camera,
}

/// Immutable tile definition for the automotive options screen.
class SettingsOptionItem {
  const SettingsOptionItem({
    required this.section,
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    required this.semanticLabelKey,
  });

  final SettingsSection section;
  final IconData icon;
  final AppTextKey titleKey;
  final AppTextKey subtitleKey;
  final AppTextKey semanticLabelKey;
}
