import 'package:carnine_frontend/features/media/presentation/player_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/album_art.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/playback_controls.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/player_timeline.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/track_info.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class PlayerCore extends StatelessWidget {
  const PlayerCore(
      {required this.controller, required this.isQueueExpanded, super.key});

  /// Growth applied to the player's core elements when the queue sidebar is
  /// collapsed and the extra width would otherwise sit empty. Kept modest so
  /// there's still room for the vertical margin below, on the fixed 600px
  /// display height.
  static const double _expandedScale = 1.1;
  static const Duration _animationDuration = Duration(milliseconds: 200);
  static const double _gap = 20;

  /// Clamps text scaling within the player core to 1.3x. This is a
  /// deliberate, documented deviation from the feature's 200% target: the
  /// player is a fixed-height, template-locked, glanceable safety surface,
  /// while the list-based screens scale fully instead.
  static const double _maxTextScale = 1.3;

  final PlayerController controller;
  final bool isQueueExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scale = isQueueExpanded ? 1.0 : _expandedScale;
    final track = controller.currentTrack;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        // On a smaller window or with the player's clamped text scale still
        // not leaving enough room (e.g. 800x480), the content scrolls
        // instead of overflowing - the fixed 1024x600 layout itself is
        // untouched, this is purely a safety net for tighter viewports.
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AlbumArt(size: 256 * scale),
                    const SizedBox(height: _gap),
                    TrackInfo(
                      title: track?.title ??
                          l10n.text(AppTextKey.mediaUnknownTitle),
                      artist: track?.artist ??
                          l10n.text(AppTextKey.mediaUnknownArtist),
                      contextLine: _contextLine(l10n),
                      scale: scale,
                    ),
                    const SizedBox(height: _gap),
                    AnimatedContainer(
                      duration: _animationDuration,
                      curve: Curves.easeOutCubic,
                      constraints: BoxConstraints(
                          maxWidth: PlaybackControls.totalWidth * scale),
                      child: PlayerTimeline(
                        position: controller.position,
                        duration: controller.duration,
                      ),
                    ),
                    const SizedBox(height: _gap),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: PlaybackControls(
                          controller: controller, scale: scale),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _contextLine(AppLocalizations l10n) {
    if (!controller.hasTrack) {
      return l10n.text(AppTextKey.mediaNothingPlaying);
    }

    final index = controller.activeQueueIndex;
    final count = controller.queue.tracks.length;
    if (index == null || count <= 1) {
      return l10n.text(AppTextKey.mediaSingleTrackLine);
    }

    return l10n.mediaQueuePositionLine(index: index + 1, count: count);
  }
}
