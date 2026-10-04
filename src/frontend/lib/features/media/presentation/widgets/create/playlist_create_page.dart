import 'package:carnine_frontend/features/media/presentation/playlist_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/create/playlist_name_page.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Name a new playlist and create it. On success the caller (`MediaContent`)
/// switches to the collections view, where `PlaylistController.
/// pendingAddEntriesTarget` immediately hands off to adding tracks - so
/// "Playlist anlegen + befüllen" reads as one uninterrupted flow.
class PlaylistCreatePage extends StatelessWidget {
  const PlaylistCreatePage({
    required this.playlists,
    required this.onBack,
    required this.onCreated,
    super.key,
  });

  final PlaylistController playlists;
  final VoidCallback onBack;
  final VoidCallback onCreated;

  Future<void> _create(String name) async {
    final id = await playlists.createPlaylist(name);
    if (id != null) {
      onCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playlists,
      builder: (context, child) => PlaylistNamePage(
        titleKey: AppTextKey.mediaPlaylistCreateAction,
        submitKey: AppTextKey.mediaCreateAction,
        submitIcon: Icons.add,
        backSemanticLabelKey: AppTextKey.mediaBackToPlayerSemantic,
        onBack: onBack,
        onSubmit: _create,
        errorKey: playlists.createErrorKey,
        isBusy: playlists.isCreating,
      ),
    );
  }
}
