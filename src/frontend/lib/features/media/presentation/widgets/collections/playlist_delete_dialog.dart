import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:flutter/material.dart';

/// Asks before a playlist is deleted - the backend has no undo.
class PlaylistDeleteDialog extends StatelessWidget {
  const PlaylistDeleteDialog({required this.playlistName, super.key});

  final String playlistName;

  /// Resolves to `true` only for **Löschen**; `false` on cancel or on
  /// dismissing the barrier.
  static Future<bool> show(BuildContext context, String playlistName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PlaylistDeleteDialog(playlistName: playlistName),
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const buttonSize = Size(96, 56);

    return AlertDialog(
      title: Text(l10n.text(AppTextKey.mediaPlaylistDeleteConfirmTitle)),
      content: Text(l10n.mediaPlaylistDeleteConfirmMessage(playlistName)),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: buttonSize),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.text(AppTextKey.mediaCancelAction)),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: buttonSize,
            foregroundColor: AppColors.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.text(AppTextKey.mediaPlaylistDeleteAction)),
        ),
      ],
    );
  }
}
