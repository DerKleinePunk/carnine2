import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/features/media/presentation/models/media_view_state.dart';
import 'package:carnine_frontend/features/media/presentation/player_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_row_tile.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_state_view.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/quick_action_tile.dart';
import 'package:carnine_frontend/features/media/presentation/format/duration_format.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

class QueueSidebar extends StatelessWidget {
  const QueueSidebar(
      {required this.controller, required this.player, super.key});

  static const Duration _animationDuration = Duration(milliseconds: 200);

  final MediaController controller;
  final PlayerController player;

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
            ),
          ),
        ),
        ClipRect(
          child: AnimatedAlign(
            duration: _animationDuration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerLeft,
            widthFactor: isExpanded ? 1 : 0,
            child: _QueuePanel(controller: controller, player: player),
          ),
        ),
      ],
    );
  }
}

class _QueueToggleButton extends StatelessWidget {
  const _QueueToggleButton({required this.isExpanded, required this.onTap});

  static const double width = 32;
  static const double _height = 88;
  static const double _iconSize = 26;

  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
  const _QueuePanel({required this.controller, required this.player});

  static const double width = 300;

  final MediaController controller;
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceContainerLow,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            const _QueueHeader(),
            Expanded(child: _QueueList(player: player)),
            _QueueQuickActions(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
  const _QueueList({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final tracks = player.queue.tracks;
    final activeIndex = player.activeQueueIndex;

    return MediaStateView(
      state: tracks.isEmpty
          ? const MediaViewState.empty(AppTextKey.mediaQueueEmpty)
          : const MediaViewState.ready(),
      builder: (context) => ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: tracks.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final track = tracks[index];
          final isActive = index == activeIndex;
          return MediaRowTile(
            title: track.title.toUpperCase(),
            subtitle: track.artist,
            semanticLabel: track.title,
            leadingIcon: isActive ? Icons.equalizer : Icons.music_note,
            isActive: isActive,
            trailing: _Duration(track: track),
            onTap: () => player.playQueueEntry(index),
          );
        },
      ),
    );
  }
}

class _Duration extends StatelessWidget {
  const _Duration({required this.track});

  final MediaLibraryTrack track;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatTrackDuration(track.duration),
      style: AppTextStyles.labelLarge.copyWith(
        color: AppColors.onSurfaceVariant,
        fontSize: 10,
      ),
    );
  }
}

class _QueueQuickActions extends StatelessWidget {
  const _QueueQuickActions({required this.controller});

  final MediaController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: QuickActionTile(
              icon: Icons.add,
              label: l10n.text(AppTextKey.mediaCreateAction).toUpperCase(),
              semanticLabel: l10n.text(AppTextKey.mediaCreateSemantic),
              onTap: () =>
                  controller.showLibraryAction(MediaLibraryAction.create),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: QuickActionTile(
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
