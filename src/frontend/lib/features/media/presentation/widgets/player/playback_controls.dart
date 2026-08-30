import 'package:carnine_frontend/features/media/presentation/player_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/control_button.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/play_pause_button.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Transport controls: shuffle, previous, rewind, play/pause, forward, next,
/// repeat.
///
/// Shuffle, repeat and the +/-30s seek buttons stay visible in their
/// template positions but are permanently disabled - the backend contract
/// has no shuffle field, no repeat field and no Seek RPC yet (see
/// `docs/20-media-backend-plan.md`). Previous/next and play/pause are wired
/// to [controller].
class PlaybackControls extends StatelessWidget {
  const PlaybackControls(
      {required this.controller, required this.scale, super.key});

  static const double sideButtonSize = 48;
  static const double centerButtonSize = 80;

  /// Gap within the transport cluster (prev/seek/play/seek/next).
  static const double innerGap = 16;

  /// Gap separating shuffle/repeat from the transport cluster, so the row
  /// reads as three groups instead of seven evenly-spaced buttons.
  static const double outerGap = 34;

  static const int _sideButtonCount = 6;
  static const int _innerGapCount = 4;
  static const int _outerGapCount = 2;

  /// Total width of this row at scale 1.0 - the timeline above it is sized
  /// to match, so the bar and time labels line up with the buttons below.
  static const double totalWidth = sideButtonSize * _sideButtonCount +
      centerButtonSize +
      innerGap * _innerGapCount +
      outerGap * _outerGapCount;

  final PlayerController controller;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final innerGapBox = SizedBox(width: innerGap * scale);
    final outerGapBox = SizedBox(width: outerGap * scale);
    final iconSize = 22 * scale;
    final buttonSize = sideButtonSize * scale;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ControlButton(
          icon: Icons.shuffle,
          semanticLabel: l10n
              .mediaUnavailableActionSemantic(AppTextKey.mediaShuffleSemantic),
          onTap: () {},
          size: buttonSize,
          iconSize: iconSize,
          isActive: false,
          isEnabled: false,
        ),
        outerGapBox,
        ControlButton(
          icon: Icons.skip_previous,
          semanticLabel: l10n.text(AppTextKey.mediaPreviousSemantic),
          onTap: controller.previous,
          size: buttonSize,
          iconSize: iconSize,
          isEnabled: controller.canGoPrevious,
        ),
        innerGapBox,
        ControlButton(
          icon: Icons.replay_30,
          semanticLabel: l10n
              .mediaUnavailableActionSemantic(AppTextKey.mediaRewind30Semantic),
          onTap: () {},
          size: buttonSize,
          iconSize: iconSize,
          isEnabled: false,
        ),
        innerGapBox,
        PlayPauseButton(
          isPlaying: controller.isPlaying,
          isEnabled: controller.hasTrack && !controller.isBusy,
          onTap: controller.togglePlayPause,
          scale: scale,
        ),
        innerGapBox,
        ControlButton(
          icon: Icons.forward_30,
          semanticLabel: l10n.mediaUnavailableActionSemantic(
              AppTextKey.mediaForward30Semantic),
          onTap: () {},
          size: buttonSize,
          iconSize: iconSize,
          isEnabled: false,
        ),
        innerGapBox,
        ControlButton(
          icon: Icons.skip_next,
          semanticLabel: l10n.text(AppTextKey.mediaNextSemantic),
          onTap: controller.next,
          size: buttonSize,
          iconSize: iconSize,
          isEnabled: controller.canGoNext,
        ),
        outerGapBox,
        ControlButton(
          icon: Icons.repeat,
          semanticLabel: l10n
              .mediaUnavailableActionSemantic(AppTextKey.mediaRepeatSemantic),
          onTap: () {},
          size: buttonSize,
          iconSize: iconSize,
          isActive: false,
          isEnabled: false,
        ),
      ],
    );
  }
}
