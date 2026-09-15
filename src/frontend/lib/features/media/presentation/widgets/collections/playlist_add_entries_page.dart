import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/presentation/library_controller.dart';
import 'package:carnine_frontend/features/media/presentation/playlist_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/collections/library_pane.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_page_header.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
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
        ListenableBuilder(
          listenable: playlists,
          builder: (context, child) {
            final hintKey = playlists.addEntryHintKey;
            if (hintKey == null) {
              return const SizedBox.shrink();
            }
            return _AlreadyAddedBanner(
              messageKey: hintKey,
              onDismiss: playlists.dismissAddEntryHint,
            );
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListenableBuilder(
              listenable: playlists,
              builder: (context, child) {
                return LibraryPane(
                  library: library,
                  onTrackTap: (track) => playlists.addEntry(
                    playlistId: playlist.id,
                    mediaId: track.id,
                  ),
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

/// Transient strip shown when tapping a track that's already in the
/// playlist - same anatomy as `AudioEventBanner`, auto-dismissed by
/// [PlaylistController] after a few seconds, or on tap.
class _AlreadyAddedBanner extends StatelessWidget {
  const _AlreadyAddedBanner({
    required this.messageKey,
    required this.onDismiss,
  });

  final AppTextKey messageKey;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: AppColors.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.text(messageKey),
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: l10n.text(AppTextKey.mediaDismiss),
              child: InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    l10n.text(AppTextKey.mediaDismiss).toUpperCase(),
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      );
    }

    if (isAdded) {
      return const Icon(Icons.check, color: AppColors.primary, size: 20);
    }

    return const Icon(
      Icons.playlist_add,
      color: AppColors.onSurfaceVariant,
      size: 20,
    );
  }
}
