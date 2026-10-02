import 'dart:async';

import 'package:carnine_frontend/features/media/presentation/playlist_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/create/playlist_name_page.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Rename [PlaylistController.renameTarget]. The name field starts with the
/// current name. Back, or a rename that works, returns to the detail page:
/// `CollectionsPage` follows [PlaylistController.renameTarget].
class PlaylistRenamePage extends StatelessWidget {
  const PlaylistRenamePage({required this.playlists, super.key});

  final PlaylistController playlists;

  @override
  Widget build(BuildContext context) {
    final target = playlists.renameTarget;
    if (target == null) {
      return const SizedBox.shrink();
    }

    return PlaylistNamePage(
      titleKey: AppTextKey.mediaPlaylistRenameAction,
      submitKey: AppTextKey.mediaSaveAction,
      submitIcon: Icons.check,
      backSemanticLabelKey: AppTextKey.mediaCancelAction,
      onBack: playlists.cancelRename,
      onSubmit: (name) => unawaited(playlists.renamePlaylist(name)),
      initialName: target.name,
      errorKey: playlists.renameErrorKey,
      isBusy: playlists.isRenaming,
    );
  }
}
