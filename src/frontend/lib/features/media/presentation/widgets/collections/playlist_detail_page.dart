import 'dart:typed_data';

import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/presentation/format/duration_format.dart';
import 'package:carnine_frontend/features/media/presentation/player_controller.dart';
import 'package:carnine_frontend/features/media/presentation/playlist_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/audio_event_banner.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/collections/playlist_delete_dialog.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_back_button.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_icon_button.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_row_tile.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_state_view.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_wide_button.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/quick_action_tile.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// One saved playlist's entries in order. Entries cannot be played from
/// here, like the player's queue sidebar - there is no direct-track-selection
/// RPC (`docs/20-media-backend-plan.md` explicitly defers it), so switching
/// tracks only ever happens through Next/Previous or restarting the
/// playlist. What a row does offer is a cross to take its entry out; the
/// header offers rename and delete (#89).
class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({
    required this.playlists,
    required this.player,
    required this.onBack,
    required this.onAddEntries,
    required this.onPlaylistStarted,
    super.key,
  });

  final PlaylistController playlists;
  final PlayerController player;
  final VoidCallback onBack;
  final void Function(MediaPlaylist playlist) onAddEntries;

  /// Called once playback of this playlist actually started, so the caller
  /// can navigate back to the main player view.
  final VoidCallback onPlaylistStarted;

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
                  _PlaylistCoverThumbnail(
                    coverArt: playlists.openPlaylistCoverArt,
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
                  MediaIconButton(
                    icon: Icons.edit,
                    semanticLabel: l10n.text(
                      AppTextKey.mediaPlaylistRenameAction,
                    ),
                    onPressed: () => playlists.startRenaming(playlist),
                  ),
                  const SizedBox(width: 8),
                  MediaIconButton(
                    icon: Icons.delete_outline,
                    color: AppColors.error,
                    semanticLabel: l10n.text(
                      AppTextKey.mediaPlaylistDeleteSemantic,
                    ),
                    onPressed: () => _confirmDelete(context, playlist),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 140,
                    height: 56,
                    child: QuickActionTile(
                      icon: Icons.play_arrow,
                      label: l10n
                          .text(AppTextKey.mediaPlaylistPlayAction)
                          .toUpperCase(),
                      semanticLabel: l10n.mediaPlaylistPlaySemantic(
                        playlist.name,
                      ),
                      isEnabled: playlist.entries.isNotEmpty && !player.isBusy,
                      onTap: () => _startPlaylist(playlist),
                    ),
                  ),
                ],
              ),
            ),
            if (playlists.actionErrorKey case final errorKey?) ...[
              const SizedBox(height: 12),
              AudioEventBanner(
                key: const ValueKey('playlist-action-error'),
                messageKey: errorKey,
                onDismiss: playlists.dismissActionError,
                isError: true,
              ),
            ],
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
                  itemBuilder: (context, index) {
                    final entry = playlist.entries[index];
                    return _EntryRow(
                      entry: entry,
                      isActive:
                          player.queue.playlistId == playlist.id &&
                          player.activeQueueIndex == index,
                      isRemoving: playlists.pendingRemoveEntryIds.contains(
                        entry.id,
                      ),
                      onRemove: () => playlists.removeEntry(entry),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: MediaWideButton(
                  icon: Icons.playlist_add,
                  label: l10n.text(AppTextKey.mediaPlaylistAddEntryAction),
                  onTap: () => onAddEntries(playlist),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MediaPlaylist playlist,
  ) async {
    final confirmed = await PlaylistDeleteDialog.show(context, playlist.name);
    if (confirmed) {
      await playlists.deletePlaylist(playlist.id);
    }
  }

  Future<void> _startPlaylist(MediaPlaylist playlist) async {
    final tracks = playlist.entries
        .map((entry) => entry.track)
        .whereType<MediaLibraryTrack>()
        .toList();
    final started = await player.playPlaylist(playlist, tracks);
    if (started) {
      onPlaylistStarted();
    }
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.isActive,
    required this.isRemoving,
    required this.onRemove,
  });

  final MediaPlaylistEntry entry;
  final bool isActive;
  final bool isRemoving;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final track = entry.track;

    if (track == null) {
      // An entry whose file is gone must be removable too, or it would stay
      // in the playlist for good.
      return MediaRowTile(
        title: l10n.text(AppTextKey.mediaPlaylistEntryUnknown),
        subtitle: '',
        semanticLabel: l10n.text(AppTextKey.mediaPlaylistEntryUnknown),
        leadingIcon: Icons.report_gmailerrorred,
        leadingIconColor: AppColors.error,
        isEnabled: false,
        trailing: _RemoveEntryButton(
          label: l10n.mediaPlaylistEntryRemoveSemantic(
            l10n.text(AppTextKey.mediaPlaylistEntryUnknown),
          ),
          isBusy: isRemoving,
          onRemove: onRemove,
        ),
      );
    }

    return MediaRowTile(
      title: track.title,
      subtitle: track.artist,
      semanticLabel: track.title,
      isActive: isActive,
      leadingIcon: isActive ? Icons.equalizer : Icons.music_note,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatTrackDuration(track.duration),
            style: AppTextStyles.labelLarge.copyWith(
              color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 8),
          _RemoveEntryButton(
            label: l10n.mediaPlaylistEntryRemoveSemantic(track.title),
            isBusy: isRemoving,
            onRemove: onRemove,
          ),
        ],
      ),
    );
  }
}

/// The cross at the end of an entry row. 56dp, without a frame: a frame on
/// every row would drown the list.
class _RemoveEntryButton extends StatelessWidget {
  const _RemoveEntryButton({
    required this.label,
    required this.isBusy,
    required this.onRemove,
  });

  final String label;
  final bool isBusy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !isBusy,
      label: label,
      child: SizedBox(
        width: 56,
        height: 56,
        child: IconButton(
          onPressed: isBusy ? null : onRemove,
          icon: const Icon(Icons.close, size: 22),
          color: AppColors.onSurfaceVariant,
          tooltip: label,
        ),
      ),
    );
  }
}

/// Playlist cover in the detail header - same 40dp leading anatomy as
/// [MediaRowTile], falling back to the queue-music icon while there is none
/// or it hasn't loaded yet.
class _PlaylistCoverThumbnail extends StatelessWidget {
  const _PlaylistCoverThumbnail({required this.coverArt});

  static const double _size = 40;

  final Uint8List? coverArt;

  @override
  Widget build(BuildContext context) {
    final art = coverArt;

    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      clipBehavior: art == null ? Clip.none : Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: art == null
          ? const Icon(
              Icons.queue_music,
              color: AppColors.onSurfaceVariant,
              size: 20,
            )
          : Image.memory(
              art,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
    );
  }
}
