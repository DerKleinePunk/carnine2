import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/features/media/presentation/models/media_track.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Media player screen based on the 1024x600 Stitch media player template.
class MediaContent extends StatefulWidget {
  const MediaContent({this.controller, super.key});

  final MediaController? controller;

  @override
  State<MediaContent> createState() => _MediaContentState();
}

class _MediaContentState extends State<MediaContent> {
  /// Minimum fling speed (logical px/s) before a horizontal drag counts as a
  /// deliberate swipe rather than an incidental touch-move.
  static const double _swipeVelocityThreshold = 200;

  static const Duration _pageSwitchDuration = Duration(milliseconds: 180);

  late final MediaController _controller =
      widget.controller ?? MediaController();

  bool get _ownsController => widget.controller == null;

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final libraryAction = _controller.openLibraryAction;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: _handleSwipe,
          child: AnimatedSwitcher(
            duration: _pageSwitchDuration,
            child: libraryAction == null
                ? Row(
                    key: const ValueKey('media-player'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _PlayerCore(controller: _controller, l10n: l10n),
                      ),
                      _QueueSidebar(controller: _controller, l10n: l10n),
                    ],
                  )
                : _MediaLibraryActionPage(
                    key: ValueKey(libraryAction),
                    action: libraryAction,
                    onBack: _controller.closeLibraryAction,
                    l10n: l10n,
                  ),
          ),
        );
      },
    );
  }

  /// Swiping right-to-left opens the queue sidebar, left-to-right closes it.
  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -_swipeVelocityThreshold && !_controller.isQueueExpanded) {
      _controller.toggleQueueExpanded();
    } else if (velocity > _swipeVelocityThreshold &&
        _controller.isQueueExpanded) {
      _controller.toggleQueueExpanded();
    }
  }
}

class _PlayerCore extends StatelessWidget {
  const _PlayerCore({required this.controller, required this.l10n});

  /// Growth applied to the player's core elements when the queue sidebar is
  /// collapsed and the extra width would otherwise sit empty. Kept modest so
  /// there's still room for the vertical margin below, on the fixed 600px
  /// display height.
  static const double _expandedScale = 1.1;
  static const Duration _animationDuration = Duration(milliseconds: 200);

  final MediaController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final track = controller.currentTrack;
    final scale = controller.isQueueExpanded ? 1.0 : _expandedScale;

    // Gaps are `Flexible` (capped at 20) rather than fixed: the 1024x600
    // display has no vertical room to spare once the scaled-up album art and
    // controls claim their space, so gaps shrink first instead of
    // overflowing the column.
    const gap = Flexible(child: SizedBox(height: 20));

    // Reserved outright (not flexible) so the controls never touch the top
    // or bottom edge, even once the gaps above have compressed.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AlbumArt(size: 256 * scale),
          gap,
          _TrackInfo(track: track, l10n: l10n, scale: scale),
          gap,
          AnimatedContainer(
            duration: _animationDuration,
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(
              maxWidth: _PlaybackControls.totalWidth * scale,
            ),
            child: _Timeline(
              position: controller.position,
              duration: track.duration,
            ),
          ),
          gap,
          _PlaybackControls(controller: controller, l10n: l10n, scale: scale),
        ],
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  const _AlbumArt({required this.size});

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

class _TrackInfo extends StatelessWidget {
  const _TrackInfo(
      {required this.track, required this.l10n, required this.scale});

  final MediaTrack track;
  final AppLocalizations l10n;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          track.title.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppTextStyles.headlineLarge.copyWith(
            color: AppColors.onSurface,
            fontSize: 32 * scale,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          track.artist.toUpperCase(),
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n
              .mediaAlbumLine(album: track.album, year: track.releaseYear)
              .toUpperCase(),
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.position, required this.duration});

  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.surfaceContainerHighest),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryFixed],
                      ),
                      boxShadow: const [
                        BoxShadow(color: AppColors.primary40, blurRadius: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TimeLabel(text: _formatDuration(position)),
            _TimeLabel(text: _formatDuration(duration)),
          ],
        ),
      ],
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelLarge.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.controller,
    required this.l10n,
    required this.scale,
  });

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

  final MediaController controller;
  final AppLocalizations l10n;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final innerGapBox = SizedBox(width: innerGap * scale);
    final outerGapBox = SizedBox(width: outerGap * scale);
    final iconSize = 22 * scale;
    final buttonSize = sideButtonSize * scale;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlButton(
          icon: Icons.shuffle,
          semanticLabel: l10n.text(AppTextKey.mediaShuffleSemantic),
          onTap: controller.toggleShuffle,
          size: buttonSize,
          iconSize: iconSize,
          isActive: controller.isShuffleEnabled,
        ),
        outerGapBox,
        _ControlButton(
          icon: Icons.skip_previous,
          semanticLabel: l10n.text(AppTextKey.mediaPreviousSemantic),
          onTap: () {},
          size: buttonSize,
          iconSize: iconSize,
        ),
        innerGapBox,
        _ControlButton(
          icon: Icons.replay_30,
          semanticLabel: l10n.text(AppTextKey.mediaRewind30Semantic),
          onTap: () => controller.seekBy(-MediaController.seekStep),
          size: buttonSize,
          iconSize: iconSize,
        ),
        innerGapBox,
        _PlayPauseButton(controller: controller, l10n: l10n, scale: scale),
        innerGapBox,
        _ControlButton(
          icon: Icons.forward_30,
          semanticLabel: l10n.text(AppTextKey.mediaForward30Semantic),
          onTap: () => controller.seekBy(MediaController.seekStep),
          size: buttonSize,
          iconSize: iconSize,
        ),
        innerGapBox,
        _ControlButton(
          icon: Icons.skip_next,
          semanticLabel: l10n.text(AppTextKey.mediaNextSemantic),
          onTap: () {},
          size: buttonSize,
          iconSize: iconSize,
        ),
        outerGapBox,
        _ControlButton(
          icon: Icons.repeat,
          semanticLabel: l10n.text(AppTextKey.mediaRepeatSemantic),
          onTap: controller.toggleRepeat,
          size: buttonSize,
          iconSize: iconSize,
          isActive: controller.isRepeatEnabled,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    required this.size,
    required this.iconSize,
    this.isActive,
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

  @override
  Widget build(BuildContext context) {
    final isOn = isActive == true;

    return Semantics(
      button: true,
      toggled: isActive,
      label: semanticLabel,
      child: Material(
        color: AppColors.surfaceContainerHigh,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.primary20),
        ),
        child: InkWell(
          onTap: onTap,
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
                    color: isOn ? AppColors.primary : AppColors.primaryDim,
                    size: iconSize,
                    shadows: isOn
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
                      child: _ToggleDot(isOn: isOn, size: iconSize * 0.22),
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
class _ToggleDot extends StatelessWidget {
  const _ToggleDot({required this.isOn, required this.size});

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

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.controller,
    required this.l10n,
    required this.scale,
  });

  static const Duration _animationDuration = Duration(milliseconds: 200);

  final MediaController controller;
  final AppLocalizations l10n;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isPlaying = controller.isPlaying;
    final label = isPlaying
        ? l10n.text(AppTextKey.mediaPauseSemantic)
        : l10n.text(AppTextKey.mediaPlaySemantic);

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: controller.togglePlayback,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: _animationDuration,
            curve: Curves.easeOutCubic,
            width: 80 * scale,
            height: 80 * scale,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryFixed],
              ),
              boxShadow: [
                BoxShadow(color: AppColors.primary40, blurRadius: 20),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: AppColors.onPrimary,
              size: 36 * scale,
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueSidebar extends StatelessWidget {
  const _QueueSidebar({required this.controller, required this.l10n});

  static const Duration _animationDuration = Duration(milliseconds: 200);

  final MediaController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isExpanded = controller.isQueueExpanded;

    // The toggle handle lives in its own fixed-width rail rather than
    // floating on top of the animated edge: at 1024px wide, straddling the
    // boundary would push half the button off the collapsed (0-width) edge
    // and off the screen entirely.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: _QueueToggleButton.width,
          child: Center(
            child: _QueueToggleButton(
              isExpanded: isExpanded,
              onTap: controller.toggleQueueExpanded,
              l10n: l10n,
            ),
          ),
        ),
        ClipRect(
          child: AnimatedAlign(
            duration: _animationDuration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerLeft,
            widthFactor: isExpanded ? 1 : 0,
            child: _QueuePanel(controller: controller, l10n: l10n),
          ),
        ),
      ],
    );
  }
}

class _QueueToggleButton extends StatelessWidget {
  const _QueueToggleButton({
    required this.isExpanded,
    required this.onTap,
    required this.l10n,
  });

  static const double width = 32;
  static const double _height = 88;
  static const double _iconSize = 26;

  final bool isExpanded;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = isExpanded
        ? l10n.text(AppTextKey.mediaQueueCollapseSemantic)
        : l10n.text(AppTextKey.mediaQueueExpandSemantic);

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          splashColor: AppColors.primary20,
          highlightColor: AppColors.surfaceContainerHighest,
          child: SizedBox(
            width: width,
            height: _height,
            child: Icon(
              isExpanded ? Icons.chevron_right : Icons.chevron_left,
              color: AppColors.primaryDim,
              size: _iconSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel({required this.controller, required this.l10n});

  static const double width = 300;

  final MediaController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceContainerLow,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            _QueueHeader(l10n: l10n),
            const Expanded(child: _QueueList()),
            _QueueQuickActions(controller: controller, l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        l10n.text(AppTextKey.mediaQueueTitle).toUpperCase(),
        style: AppTextStyles.headlineLarge.copyWith(
          color: AppColors.onSurface,
          fontSize: 14,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: MediaController.queue.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final track = MediaController.queue[index];
        return _QueueTile(track: track, isActive: index == 0);
      },
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({required this.track, required this.isActive});

  final MediaTrack track;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isActive ? AppColors.surfaceContainerHighest : null,
        borderRadius: BorderRadius.circular(8),
        border: isActive
            ? const Border(
                left: BorderSide(color: AppColors.primary, width: 2),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _QueueTileArt(isActive: isActive),
            const SizedBox(width: 12),
            Expanded(child: _QueueTileLabels(track: track, isActive: isActive)),
            Text(
              _formatDuration(track.duration),
              style: AppTextStyles.labelLarge.copyWith(
                color:
                    isActive ? AppColors.primary : AppColors.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueTileArt extends StatelessWidget {
  const _QueueTileArt({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        isActive ? Icons.equalizer : Icons.music_note,
        color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
        size: 20,
      ),
    );
  }
}

class _QueueTileLabels extends StatelessWidget {
  const _QueueTileLabels({required this.track, required this.isActive});

  final MediaTrack track;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelLarge.copyWith(
            color: isActive ? AppColors.primary : AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _QueueQuickActions extends StatelessWidget {
  const _QueueQuickActions({required this.controller, required this.l10n});

  final MediaController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionTile(
              icon: Icons.add,
              label: l10n.text(AppTextKey.mediaCreateAction).toUpperCase(),
              semanticLabel: l10n.text(AppTextKey.mediaCreateSemantic),
              onTap: () =>
                  controller.showLibraryAction(MediaLibraryAction.create),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionTile(
              icon: Icons.library_music,
              label: l10n.text(AppTextKey.mediaCollectionsTitle).toUpperCase(),
              semanticLabel: l10n.text(AppTextKey.mediaCollectionsSemantic),
              onTap: () =>
                  controller.showLibraryAction(MediaLibraryAction.collections),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            splashColor: AppColors.primary20,
            highlightColor: AppColors.surfaceContainerHigh,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.primary, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
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

/// Full-screen placeholder shown for a library quick action, until the real
/// create/collections features exist.
class _MediaLibraryActionPage extends StatelessWidget {
  const _MediaLibraryActionPage({
    required this.action,
    required this.onBack,
    required this.l10n,
    super.key,
  });

  final MediaLibraryAction action;
  final VoidCallback onBack;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (icon, titleKey, bodyKey) = switch (action) {
      MediaLibraryAction.create => (
          Icons.add,
          AppTextKey.mediaCreateComingSoonTitle,
          AppTextKey.mediaCreateComingSoonDescription,
        ),
      MediaLibraryAction.collections => (
          Icons.library_music,
          AppTextKey.mediaCollectionsComingSoonTitle,
          AppTextKey.mediaCollectionsComingSoonDescription,
        ),
    };

    return ColoredBox(
      color: AppColors.surface,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.onSurfaceVariant, size: 54),
                const SizedBox(height: 18),
                Text(
                  l10n.text(titleKey),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: AppColors.onSurface,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.text(bodyKey),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: _MockPageBackButton(onBack: onBack, l10n: l10n),
          ),
        ],
      ),
    );
  }
}

class _MockPageBackButton extends StatelessWidget {
  const _MockPageBackButton({required this.onBack, required this.l10n});

  final VoidCallback onBack;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = l10n.text(AppTextKey.mediaBackToPlayerSemantic);

    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: 56,
        height: 56,
        child: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 26),
          color: AppColors.primary,
          tooltip: label,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceContainerHighest,
            side: const BorderSide(color: AppColors.primary20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
