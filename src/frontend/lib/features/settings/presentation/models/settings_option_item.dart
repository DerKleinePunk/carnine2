import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

enum SettingsSection {
  language,
  diagnostics,
  appearance,
  maps,
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
