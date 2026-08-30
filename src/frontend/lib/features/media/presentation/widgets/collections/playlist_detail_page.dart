import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/presentation/format/duration_format.dart';
import 'package:carnine_frontend/features/media/presentation/player_controller.dart';
import 'package:carnine_frontend/features/media/presentation/playlist_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_back_button.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_row_tile.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_state_view.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/quick_action_tile.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// One saved playlist's entries in order. Entries are display-only, like
/// the player's queue sidebar - there is no direct-track-selection RPC
/// (`docs/20-media-backend-plan.md` explicitly defers it), so switching
/// tracks only ever happens through Next/Previous or restarting the
/// playlist.
class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({
    required this.playlists,
    required this.player,
    required this.onBack,
    required this.onAddEntries,
    super.key,
  });

  final PlaylistController playlists;
  final PlayerController player;
  final VoidCallback onBack;
  final void Function(MediaPlaylist playlist) onAddEntries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([playlists, player]),
      builder: (context, child) {
        final playlist = playlists.openPlaylist;
        if (playlist == null) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  MediaBackButton(
                    onBack: onBack,
                    semanticLabelKey: AppTextKey.mediaBackToCollectionsSemantic,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      playlist.name.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: AppColors.onSurface,
                        fontSize: 14,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    height: 56,
                    child: QuickActionTile(
                      icon: Icons.play_arrow,
                      label: l10n
                          .text(AppTextKey.mediaPlaylistPlayAction)
                          .toUpperCase(),
                      semanticLabel:
                          l10n.mediaPlaylistPlaySemantic(playlist.name),
                      isEnabled: playlist.entries.isNotEmpty && !player.isBusy,
                      onTap: () => _startPlaylist(playlist),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: MediaStateView(
                state: playlists.detailState,
                onRetry: () => playlists.openPlaylistById(playlist.id),
                builder: (context) => ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: playlist.entries.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) => _EntryRow(
                    entry: playlist.entries[index],
                    isActive: player.queue.playlistId == playlist.id &&
                        player.activeQueueIndex == index,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: _AddEntriesButton(onTap: () => onAddEntries(playlist)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _startPlaylist(MediaPlaylist playlist) {
    final tracks = playlist.entries
        .map((entry) => entry.track)
        .whereType<MediaLibraryTrack>()
        .toList();
    player.playPlaylist(playlist, tracks);
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.isActive});

  final MediaPlaylistEntry entry;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final track = entry.track;

    if (track == null) {
      return MediaRowTile(
        title: l10n.text(AppTextKey.mediaPlaylistEntryUnknown),
        subtitle: '',
        semanticLabel: l10n.text(AppTextKey.mediaPlaylistEntryUnknown),
        leadingIcon: Icons.report_gmailerrorred,
        leadingIconColor: AppColors.error,
        isEnabled: false,
      );
    }

    return MediaRowTile(
      title: track.title,
      subtitle: track.artist,
      semanticLabel: track.title,
      isActive: isActive,
      leadingIcon: isActive ? Icons.equalizer : Icons.music_note,
      trailing: Text(
        formatTrackDuration(track.duration),
        style: AppTextStyles.labelLarge.copyWith(
          color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _AddEntriesButton extends StatelessWidget {
  const _AddEntriesButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = l10n.text(AppTextKey.mediaPlaylistAddEntryAction);

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: AppColors.primary20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.playlist_add,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
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
