import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';

class ControlButton extends StatelessWidget {
  const ControlButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    required this.size,
    required this.iconSize,
    this.isActive,
    this.isEnabled = true,
    this.isIneffective = false,
    super.key,
  });

  static const Duration _animationDuration = Duration(milliseconds: 200);

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  /// Null for a plain action button. For a toggle (shuffle/repeat), whether
  /// it is currently switched on - also drives the icon's accent color, its
  /// subtle glow, and the small dot below it.
  final bool? isActive;

  final bool isEnabled;

  /// A toggle that is on but does nothing for the moment (shuffle while one
  /// track repeats, #143): the icon is pale, without its glow, and the dot
  /// below it is a ring.
  final bool isIneffective;

  @override
  Widget build(BuildContext context) {
    final isOn = isActive == true;
    // A toggle (isActive non-null, e.g. shuffle/repeat) reads as clearly
    // off (outline grey) or on (primary) - a plain action button (prev,
    // next, the disabled seek buttons) keeps the softer primaryDim it
    // always had, since it has no on/off state to distinguish.
    final iconColor = !isEnabled
        ? AppColors.outline
        : isActive == null
        ? AppColors.primaryDim
        : (isOn
              ? (isIneffective
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : AppColors.primary)
              : AppColors.outline);

    return Semantics(
      button: true,
      enabled: isEnabled,
      toggled: isActive,
      label: semanticLabel,
      child: Material(
        color: AppColors.surfaceContainerHigh,
        shape: const CircleBorder(side: BorderSide(color: AppColors.primary20)),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          customBorder: const CircleBorder(),
          splashColor: AppColors.primary20,
          highlightColor: AppColors.surfaceContainerHighest,
          child: AnimatedContainer(
            duration: _animationDuration,
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            // `Stack` sized explicitly to the full button (not just its
            // icon child) so the `Positioned` dot below measures from the
            // button's true bottom edge instead of the icon's own bounds.
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    color: iconColor,
                    size: iconSize,
                    shadows: isOn && isEnabled && !isIneffective
                        ? const [
                            Shadow(color: AppColors.primary40, blurRadius: 10),
                          ]
                        : null,
                  ),
                  if (isActive != null)
                    Positioned(
                      bottom: size * 0.16,
                      child: ToggleDot(
                        isOn: isOn && isEnabled,
                        isRing: isIneffective,
                        size: iconSize * 0.22,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small active-state indicator below a toggle icon, Spotify-style.
class ToggleDot extends StatelessWidget {
  const ToggleDot({
    required this.isOn,
    required this.size,
    this.isRing = false,
    super.key,
  });

  static const Duration _animationDuration = Duration(milliseconds: 200);

  final bool isOn;
  final double size;

  /// An outline instead of a filled dot, without its glow.
  final bool isRing;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: _animationDuration,
      opacity: isOn ? 1 : 0,
      child: Container(
        width: size,
        height: size,
        decoration: isRing
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 1),
              )
            : const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(color: AppColors.primary40, blurRadius: 6),
                ],
              ),
      ),
    );
  }
}
