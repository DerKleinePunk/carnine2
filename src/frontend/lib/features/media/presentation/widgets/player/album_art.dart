import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';

class AlbumArt extends StatelessWidget {
  const AlbumArt({required this.size, super.key});

  static const Duration _animationDuration = Duration(milliseconds: 200);

  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.secondary20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceContainerHigh,
            AppColors.surfaceContainerHighest,
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.secondary20,
            blurRadius: 50,
            spreadRadius: -10,
          ),
          BoxShadow(
            color: AppColors.secondary40,
            blurRadius: 24,
            spreadRadius: -18,
          ),
        ],
      ),
      child: Icon(
        Icons.graphic_eq_rounded,
        size: size * 0.375,
        color: AppColors.primary,
      ),
    );
  }
}
