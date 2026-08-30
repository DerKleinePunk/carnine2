import 'package:carnine_frontend/features/media/domain/models/media_library_track.dart';
import 'package:carnine_frontend/features/media/presentation/format/duration_format.dart';
import 'package:carnine_frontend/features/media/presentation/library_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/collections/library_search_field.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/collections/scan_status_bar.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_row_tile.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_state_view.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/quick_action_tile.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Search + rescan + results. Reused unmodified as the picker for "add
/// tracks to a playlist" by swapping [onTrackTap]/[trailingBuilder].
class LibraryPane extends StatelessWidget {
  const LibraryPane({
    required this.library,
    required this.onTrackTap,
    this.trailingBuilder,
    super.key,
  });

  final LibraryController library;
  final void Function(MediaLibraryTrack track) onTrackTap;

  /// Overrides the default duration+play trailing for a row. Used by the
  /// add-entries picker to show an add/added/pending action instead.
  final Widget? Function(MediaLibraryTrack track)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: library,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                    child:
                        LibrarySearchField(onChanged: library.onQueryChanged)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: QuickActionTile(
                    icon: Icons.refresh,
                    label:
                        l10n.text(AppTextKey.mediaRescanAction).toUpperCase(),
                    semanticLabel: l10n.text(AppTextKey.mediaRescanSemantic),
                    isEnabled: !library.isScanning,
                    onTap: library.rescan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ScanStatusBar(
              isScanning: library.isScanning,
              processed: library.scanProcessed,
              imported: library.scanImported,
              failedPath: library.scanFailedPath,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: MediaStateView(
                state: library.state,
                onRetry: library.retry,
                builder: (context) => ListView.separated(
                  itemCount: library.results.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) => _LibraryRow(
                    track: library.results[index],
                    onTap: onTrackTap,
                    trailing: trailingBuilder,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow(
      {required this.track, required this.onTap, required this.trailing});

  final MediaLibraryTrack track;
  final void Function(MediaLibraryTrack track) onTap;
  final Widget? Function(MediaLibraryTrack track)? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPlayable = track.isPlayable;

    return MediaRowTile(
      title: track.title,
      subtitle: track.artist,
      semanticLabel: isPlayable
          ? l10n.mediaPlayTrackSemantic(track.title)
          : l10n.mediaUnavailableSemantic(track.title),
      isEnabled: isPlayable,
      leadingIcon: isPlayable ? Icons.music_note : Icons.report_gmailerrorred,
      leadingIconColor: isPlayable ? null : AppColors.error,
      onTap: isPlayable ? () => onTap(track) : null,
      trailing: trailing?.call(track) ?? _DefaultTrailing(track: track),
    );
  }
}

class _DefaultTrailing extends StatelessWidget {
  const _DefaultTrailing({required this.track});

  final MediaLibraryTrack track;

  @override
  Widget build(BuildContext context) {
    if (!track.isPlayable) {
      final l10n = AppLocalizations.of(context);
      return Text(
        l10n.text(AppTextKey.mediaUnavailableBadge),
        style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.error,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatTrackDuration(track.duration),
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.play_arrow, color: AppColors.primary, size: 18),
      ],
    );
  }
}
