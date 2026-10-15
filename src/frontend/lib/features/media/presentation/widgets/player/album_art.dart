import 'dart:typed_data';

import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';

/// The current track's artwork, or the design system's placeholder
/// (glowing equalizer icon) while it has none or hasn't loaded yet -
/// [coverArt] is `null` in both cases, indistinguishably, since the fallback
/// looks identical either way.
class AlbumArt extends StatelessWidget {
  const AlbumArt({required this.size, this.coverArt, super.key});

  static const Duration _animationDuration = Duration(milliseconds: 200);

  final double size;
  final Uint8List? coverArt;

  @override
  Widget build(BuildContext context) {
    final art = coverArt;

    return AnimatedContainer(
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: art == null ? Clip.none : Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
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
      child: art == null
          ? Icon(
              Icons.graphic_eq_rounded,
              size: size * 0.375,
              color: AppColors.primary,
            )
          : Image.memory(
              art,
              width: size,
              height: size,
              // Decoded at the size it is shown, not the file's (a 1000 px
              // cover is 4 MB decoded, also for the 72 px tile). Width only,
              // so a cover that is not square keeps its proportions.
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .ceil(),
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
    );
  }
}
