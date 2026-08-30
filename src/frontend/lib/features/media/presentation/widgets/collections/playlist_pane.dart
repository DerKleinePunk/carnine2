import 'package:carnine_frontend/features/media/domain/models/media_playlist.dart';
import 'package:carnine_frontend/features/media/presentation/playlist_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_row_tile.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_state_view.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';

class PlaylistPane extends StatelessWidget {
  const PlaylistPane({
    required this.controller,
    required this.onOpen,
    required this.onPlay,
    super.key,
  });

  final PlaylistController controller;
  final void Function(int playlistId) onOpen;
  final void Function(MediaPlaylist playlist) onPlay;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return MediaStateView(
          state: controller.listState,
          onRetry: controller.loadPlaylists,
          builder: (context) => ListView.separated(
            itemCount: controller.playlists.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final playlist = controller.playlists[index];
              return _PlaylistRow(
                  playlist: playlist, onOpen: onOpen, onPlay: onPlay);
            },
          ),
        );
      },
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow(
      {required this.playlist, required this.onOpen, required this.onPlay});

  final MediaPlaylist playlist;
  final void Function(int playlistId) onOpen;
  final void Function(MediaPlaylist playlist) onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return MediaRowTile(
      title: playlist.name,
      subtitle: '',
      leadingIcon: Icons.queue_music,
      semanticLabel: l10n.mediaPlaylistOpenSemantic(playlist.name),
      onTap: () => onOpen(playlist.id),
      trailing: Semantics(
        button: true,
        label: l10n.mediaPlaylistPlaySemantic(playlist.name),
        child: IconButton(
          icon: const Icon(Icons.play_arrow, color: AppColors.primary),
          onPressed: () => onPlay(playlist),
        ),
      ),
    );
  }
}
