import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';

/// Compact top bar with system indicators and diagnostics access.
class CarnineTopBar extends StatelessWidget {
  const CarnineTopBar({
    required this.onShowLogs,
    super.key,
  });

  final VoidCallback onShowLogs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const _StatusIcon(icon: Icons.signal_cellular_4_bar),
            const _StatusIcon(icon: Icons.battery_full),
            const _StatusIcon(icon: Icons.light_mode),
            const SizedBox(width: 12),
            IconButton(
              onPressed: onShowLogs,
              icon: const Icon(Icons.article, size: 16),
              color: AppColors.primary,
              tooltip: 'Show frontend logs',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Icon(icon, color: AppColors.primary, size: 12),
    );
  }
}
