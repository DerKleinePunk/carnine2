import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';

/// Round map button in the look of the Stitch template (48 px circle) with a
/// 76 dp touch target around it - the in-vehicle minimum from
/// `src/frontend/CLAUDE.md`.
class MapIconButton extends StatelessWidget {
  const MapIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.color,
    required this.onTap,
    this.active = false,
    super.key,
  });

  static const double _visibleSize = 48;
  static const double _touchSize = 76;

  final IconData icon;
  final String semanticLabel;
  final Color color;
  final VoidCallback? onTap;

  /// Highlights the ring, e.g. while navigation mode is on.
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: _touchSize,
          child: Center(child: _circle()),
        ),
      ),
    );
  }

  Widget _circle() {
    return Container(
      width: _visibleSize,
      height: _visibleSize,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? color : AppColors.primary20,
          width: active ? 2 : 1,
        ),
      ),
      child: Icon(
        icon,
        size: 22,
        color: onTap == null ? AppColors.onSurfaceVariant : color,
      ),
    );
  }
}
