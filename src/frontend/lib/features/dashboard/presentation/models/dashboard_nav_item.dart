import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

enum DashboardDestination {
  home,
  maps,
  media,
  climate,
  controls,
  settings,
}

/// Immutable side-menu destination used by the dashboard presentation layer.
class DashboardNavItem {
  const DashboardNavItem({
    required this.destination,
    required this.icon,
    required this.labelKey,
    required this.semanticLabelKey,
  });

  final DashboardDestination destination;
  final IconData icon;
  final AppTextKey labelKey;
  final AppTextKey semanticLabelKey;
}
