import 'package:carnine_frontend/core/keyboard/on_screen_text_field.dart';
import 'package:carnine_frontend/features/media/presentation/playlist_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_back_button.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Name a new playlist and create it. On success the caller (`MediaContent`)
/// switches to the collections view, where `PlaylistController.
/// pendingAddEntriesTarget` immediately hands off to adding tracks - so
/// "Playlist anlegen + befüllen" reads as one uninterrupted flow.
class PlaylistCreatePage extends StatefulWidget {
  const PlaylistCreatePage({
    required this.playlists,
    required this.onBack,
    required this.onCreated,
    super.key,
  });

  final PlaylistController playlists;
  final VoidCallback onBack;
  final VoidCallback onCreated;

  @override
  State<PlaylistCreatePage> createState() => _PlaylistCreatePageState();
}

class _PlaylistCreatePageState extends State<PlaylistCreatePage> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final id = await widget.playlists.createPlaylist(_nameController.text);
    if (id != null) {
      widget.onCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: widget.playlists,
      builder: (context, child) {
        final errorKey = widget.playlists.createErrorKey;

        return ColoredBox(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MediaBackButton(
                      onBack: widget.onBack,
                      semanticLabelKey: AppTextKey.mediaBackToPlayerSemantic,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n
                          .text(AppTextKey.mediaPlaylistCreateAction)
                          .toUpperCase(),
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: AppColors.onSurface,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                OnScreenTextField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 40,
                  onSubmitted: (_) => _create(),
                  semanticLabel: l10n.text(AppTextKey.mediaPlaylistNameHint),
                  hintText: l10n.text(AppTextKey.mediaPlaylistNameHint),
                ),
                if (errorKey != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.text(errorKey),
                    style: AppTextStyles.bodyLarge
                        .copyWith(color: AppColors.error, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
