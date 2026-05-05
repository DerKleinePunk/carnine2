import 'package:flutter/material.dart';

/// Immutable side-menu destination used by the dashboard presentation layer.
class DashboardNavItem {
  const DashboardNavItem({
    required this.label,
    required this.icon,
    required this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final String semanticLabel;
}
