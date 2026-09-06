import 'package:carnine_frontend/features/media/presentation/library_controller.dart';
import 'package:carnine_frontend/features/media/presentation/player_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/collections/library_pane.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_page_header.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The "Bibliothek" sub-page: every track found on disk, searchable and
/// individually playable, with a manual rescan action - split out of
/// "Sammlungen" (which now only lists existing playlists).
class LibraryPage extends StatelessWidget {
  const LibraryPage({
    required this.library,
    required this.player,
    required this.onBack,
    super.key,
  });

  final LibraryController library;
  final PlayerController player;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaPageHeader(
          titleKey: AppTextKey.mediaLibraryTitle,
          onBack: onBack,
          backSemanticLabelKey: AppTextKey.mediaBackToPlayerSemantic,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: LibraryPane(library: library, onTrackTap: player.playTrack),
          ),
        ),
      ],
    );
  }
}
