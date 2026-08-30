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

  @override
  Widget build(BuildContext context) {
    final isOn = isActive == true;
    final iconColor = !isEnabled
        ? AppColors.outline
        : (isOn ? AppColors.primary : AppColors.primaryDim);

    return Semantics(
      button: true,
      enabled: isEnabled,
      toggled: isActive,
      label: semanticLabel,
      child: Material(
        color: AppColors.surfaceContainerHigh,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.primary20),
        ),
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
                    shadows: isOn && isEnabled
                        ? const [
                            Shadow(
                              color: AppColors.primary40,
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  if (isActive != null)
                    Positioned(
                      bottom: size * 0.16,
                      child: ToggleDot(
                          isOn: isOn && isEnabled, size: iconSize * 0.22),
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
  const ToggleDot({required this.isOn, required this.size, super.key});

  static const Duration _animationDuration = Duration(milliseconds: 200);

  final bool isOn;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: _animationDuration,
      opacity: isOn ? 1 : 0,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
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
