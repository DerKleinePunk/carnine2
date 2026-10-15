import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';

/// The switch drawn on a card or a row: it shows the state and takes no
/// touch of its own - the card or row around it does. Lit when it is on and
/// [isAvailable].
class MiniSwitch extends StatelessWidget {
  const MiniSwitch({required this.isOn, this.isAvailable = true, super.key});

  final bool isOn;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final isLit = isAvailable && isOn;

    return Container(
      width: 56,
      height: 30,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isLit ? AppColors.primary40 : AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isLit ? AppColors.primary : AppColors.outlineVariant20,
        ),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 150),
        alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: !isAvailable
                ? AppColors.outline
                : (isOn ? AppColors.primary : AppColors.onSurfaceVariant),
          ),
          child: const SizedBox(width: 20, height: 20),
        ),
      ),
    );
  }
}
