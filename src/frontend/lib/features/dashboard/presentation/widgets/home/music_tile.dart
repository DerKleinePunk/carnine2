import 'dart:async';

import 'package:carnine_frontend/features/dashboard/presentation/widgets/home/home_tile.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/features/media/presentation/player_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/album_art.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/control_button.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/play_pause_button.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// The music tile of the start page (#94): cover, title, artist, progress and
/// the buttons previous, play or pause, and next. A tap anywhere else opens
/// the Medien page. Without a track it says so and the buttons are grey.
class MusicTile extends StatelessWidget {
  const MusicTile({required this.controller, required this.onTap, super.key});

  final MediaController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final player = controller.player;

    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => HomeTile(
        title: l10n.text(AppTextKey.homeMusicTitle),
        onTap: onTap,
        child: _Player(player: player),
      ),
    );
  }
}

class _Player extends StatelessWidget {
  const _Player({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final track = player.currentTrack;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            children: [
              AlbumArt(size: 72, coverArt: player.currentTrackCoverArt),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track?.title ?? l10n.text(AppTextKey.mediaNothingPlaying),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: AppColors.onSurface,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track?.artist ?? l10n.text(AppTextKey.homeMusicOpenMedia),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: track == null
                            ? AppColors.onSurfaceVariant
                            : AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Progress(value: track == null ? 0 : player.progress),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ControlButton(
              icon: Icons.skip_previous,
              semanticLabel: l10n.text(AppTextKey.mediaPreviousSemantic),
              onTap: () => unawaited(player.previous()),
              size: 48,
              iconSize: 26,
              isEnabled: player.canGoPrevious,
            ),
            PlayPauseButton(
              isPlaying: player.isPlaying,
              isEnabled: player.hasTrack && !player.isBusy,
              onTap: () => unawaited(player.togglePlayPause()),
              scale: 0.7,
            ),
            ControlButton(
              icon: Icons.skip_next,
              semanticLabel: l10n.text(AppTextKey.mediaNextSemantic),
              onTap: () => unawaited(player.next()),
              size: 48,
              iconSize: 26,
              isEnabled: player.canGoNext,
            ),
          ],
        ),
      ],
    );
  }
}

/// How far the track has come; only shows, does not seek.
class _Progress extends StatelessWidget {
  const _Progress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 4,
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceContainerHighest,
      ),
    );
  }
}
