import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';

/// Compact top bar with system indicators.
class CarnineTopBar extends StatelessWidget {
  const CarnineTopBar({super.key});

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
