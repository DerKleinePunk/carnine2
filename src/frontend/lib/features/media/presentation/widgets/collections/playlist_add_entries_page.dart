import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/presentation/library_controller.dart';
import 'package:carnine_frontend/features/media/presentation/playlist_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/collections/library_pane.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_page_header.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';

/// Reuses [LibraryPane] to add media items to [playlist], swapping the
/// default duration+play trailing for an add/added/pending action.
class PlaylistAddEntriesPage extends StatelessWidget {
  const PlaylistAddEntriesPage({
    required this.playlist,
    required this.library,
    required this.playlists,
    required this.onBack,
    super.key,
  });

  final MediaPlaylist playlist;
  final LibraryController library;
  final PlaylistController playlists;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaPageHeader(
          titleKey: AppTextKey.mediaPlaylistAddEntriesTitle,
          onBack: onBack,
          backSemanticLabelKey: AppTextKey.mediaBackToCollectionsSemantic,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListenableBuilder(
              listenable: playlists,
              builder: (context, child) {
                return LibraryPane(
                  library: library,
                  onTrackTap: (track) => playlists.addEntry(
                      playlistId: playlist.id, mediaId: track.id),
                  trailingBuilder: (track) => _AddAction(
                    isPending: playlists.pendingAddMediaIds.contains(track.id),
                    isAdded: playlists.addedMediaIds.contains(track.id),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AddAction extends StatelessWidget {
  const _AddAction({required this.isPending, required this.isAdded});

  final bool isPending;
  final bool isAdded;

  @override
  Widget build(BuildContext context) {
    if (isPending) {
      return const SizedBox(
        width: 18,
        height: 18,
        child:
            CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
      );
    }

    if (isAdded) {
      return const Icon(Icons.check, color: AppColors.primary, size: 20);
    }

    return const Icon(Icons.playlist_add,
        color: AppColors.onSurfaceVariant, size: 20);
  }
}
