import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/presentation/library_controller.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/features/media/presentation/player_controller.dart';
import 'package:carnine_frontend/features/media/presentation/playlist_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/collections/playlist_add_entries_page.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/collections/playlist_detail_page.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/collections/playlist_pane.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_page_header.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/quick_action_tile.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The "Sammlungen" sub-page: the list of existing playlists, plus playlist
/// detail and add-entries as nested views. Browsing individual library
/// tracks lives in its own `LibraryPage` now, not here.
///
/// Navigation between playlist overview/detail/add-entries is driven by
/// [PlaylistController] state directly (`openPlaylist`,
/// `pendingAddEntriesTarget`) rather than separate widget state, so a
/// playlist opened here stays open across a rebuild for any reason.
class CollectionsPage extends StatelessWidget {
  const CollectionsPage({
    required this.controller,
    required this.library,
    required this.player,
    required this.playlists,
    required this.onBack,
    super.key,
  });

  final MediaController controller;
  final LibraryController library;
  final PlayerController player;
  final PlaylistController playlists;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playlists,
      builder: (context, child) {
        final addEntriesTarget = playlists.pendingAddEntriesTarget;
        if (addEntriesTarget != null) {
          return PlaylistAddEntriesPage(
            playlist: addEntriesTarget,
            library: library,
            playlists: playlists,
            onBack: playlists.consumePendingAddEntriesTarget,
          );
        }

        if (playlists.openPlaylist != null) {
          return PlaylistDetailPage(
            playlists: playlists,
            player: player,
            onBack: playlists.closePlaylist,
            onAddEntries: playlists.startAddingEntries,
          );
        }

        return _Overview(
          player: player,
          playlists: playlists,
          onBack: onBack,
          onCreate: () =>
              controller.showLibraryAction(MediaLibraryAction.create),
        );
      },
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.player,
    required this.playlists,
    required this.onBack,
    required this.onCreate,
  });

  final PlayerController player;
  final PlaylistController playlists;
  final VoidCallback onBack;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaPageHeader(
          titleKey: AppTextKey.mediaCollectionsTitle,
          onBack: onBack,
          backSemanticLabelKey: AppTextKey.mediaBackToPlayerSemantic,
          trailing: SizedBox(
            width: 56,
            height: 56,
            child: QuickActionTile(
              icon: Icons.add,
              semanticLabel: l10n.text(AppTextKey.mediaCreateSemantic),
              onTap: onCreate,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: PlaylistPane(
              controller: playlists,
              onOpen: playlists.openPlaylistById,
              onPlay: _startPlaylist,
            ),
          ),
        ),
      ],
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
