import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/presentation/library_controller.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/features/media/presentation/player_controller.dart';
import 'package:carnine_frontend/features/media/presentation/playlist_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/collections/library_pane.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/collections/playlist_add_entries_page.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/collections/playlist_detail_page.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/collections/playlist_pane.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_page_header.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/quick_action_tile.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The "Sammlungen" sub-page: the library (search/rescan/results) and
/// playlists, plus playlist detail and add-entries as nested views.
///
/// Navigation between playlist overview/detail/add-entries is driven by
/// [PlaylistController] state directly (`openPlaylist`,
/// `pendingAddEntriesTarget`) rather than separate widget state, so a
/// playlist opened here stays open across a rebuild for any reason.
class CollectionsPage extends StatefulWidget {
  const CollectionsPage({
    required this.controller,
    required this.library,
    required this.player,
    required this.playlists,
    required this.onBack,
    super.key,
  });

  static const double _wideBreakpoint = 820;

  final MediaController controller;
  final LibraryController library;
  final PlayerController player;
  final PlaylistController playlists;
  final VoidCallback onBack;

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  bool _showPlaylistsOnNarrow = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.playlists,
      builder: (context, child) {
        final addEntriesTarget = widget.playlists.pendingAddEntriesTarget;
        if (addEntriesTarget != null) {
          return PlaylistAddEntriesPage(
            playlist: addEntriesTarget,
            library: widget.library,
            playlists: widget.playlists,
            onBack: widget.playlists.consumePendingAddEntriesTarget,
          );
        }

        if (widget.playlists.openPlaylist != null) {
          return PlaylistDetailPage(
            playlists: widget.playlists,
            player: widget.player,
            onBack: widget.playlists.closePlaylist,
            onAddEntries: widget.playlists.startAddingEntries,
          );
        }

        return _Overview(
          library: widget.library,
          player: widget.player,
          playlists: widget.playlists,
          onBack: widget.onBack,
          showPlaylistsOnNarrow: _showPlaylistsOnNarrow,
          onToggleNarrowPane: (showPlaylists) {
            setState(() => _showPlaylistsOnNarrow = showPlaylists);
          },
        );
      },
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.library,
    required this.player,
    required this.playlists,
    required this.onBack,
    required this.showPlaylistsOnNarrow,
    required this.onToggleNarrowPane,
  });

  final LibraryController library;
  final PlayerController player;
  final PlaylistController playlists;
  final VoidCallback onBack;
  final bool showPlaylistsOnNarrow;
  final void Function(bool showPlaylists) onToggleNarrowPane;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaPageHeader(
          titleKey: AppTextKey.mediaCollectionsTitle,
          onBack: onBack,
          backSemanticLabelKey: AppTextKey.mediaBackToPlayerSemantic,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= CollectionsPage._wideBreakpoint) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          flex: 3,
                          child: LibraryPane(
                              library: library, onTrackTap: player.playTrack)),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: PlaylistPane(
                          controller: playlists,
                          onOpen: playlists.openPlaylistById,
                          onPlay: _startPlaylist,
                        ),
                      ),
                    ],
                  );
                }

                return _NarrowOverview(
                  library: library,
                  player: player,
                  playlists: playlists,
                  showPlaylists: showPlaylistsOnNarrow,
                  onToggle: onToggleNarrowPane,
                  onPlayPlaylist: _startPlaylist,
                );
              },
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

class _NarrowOverview extends StatelessWidget {
  const _NarrowOverview({
    required this.library,
    required this.player,
    required this.playlists,
    required this.showPlaylists,
    required this.onToggle,
    required this.onPlayPlaylist,
  });

  final LibraryController library;
  final PlayerController player;
  final PlaylistController playlists;
  final bool showPlaylists;
  final void Function(bool showPlaylists) onToggle;
  final void Function(MediaPlaylist playlist) onPlayPlaylist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                child: QuickActionTile(
                  icon: Icons.library_music,
                  label: l10n.text(AppTextKey.mediaLibraryTitle).toUpperCase(),
                  semanticLabel: l10n.text(AppTextKey.mediaLibraryTitle),
                  isEnabled: showPlaylists,
                  onTap: () => onToggle(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: QuickActionTile(
                  icon: Icons.queue_music,
                  label:
                      l10n.text(AppTextKey.mediaPlaylistsTitle).toUpperCase(),
                  semanticLabel: l10n.text(AppTextKey.mediaPlaylistsTitle),
                  isEnabled: !showPlaylists,
                  onTap: () => onToggle(true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: showPlaylists
              ? PlaylistPane(
                  controller: playlists,
                  onOpen: playlists.openPlaylistById,
                  onPlay: onPlayPlaylist,
                )
              : LibraryPane(library: library, onTrackTap: player.playTrack),
        ),
      ],
    );
  }
}
