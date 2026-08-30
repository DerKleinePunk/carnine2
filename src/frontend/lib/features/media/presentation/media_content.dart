import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/collections/collections_page.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/create/playlist_create_page.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/media_connection_banner.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/player_page.dart';
import 'package:flutter/material.dart';

/// Media player screen based on the 1024x600 Stitch media player template.
///
/// A thin shell: swipe handling, page switching between the player and its
/// library-action sub-pages, and the connection-loss banner. All actual
/// content lives in `widgets/player/` and `widgets/collections/`, driven by
/// [MediaController] and its player/library/playlist sub-controllers.
class MediaContent extends StatefulWidget {
  const MediaContent({this.controller, super.key});

  final MediaController? controller;

  @override
  State<MediaContent> createState() => _MediaContentState();
}

class _MediaContentState extends State<MediaContent> {
  /// Minimum fling speed (logical px/s) before a horizontal drag counts as a
  /// deliberate swipe rather than an incidental touch-move.
  static const double _swipeVelocityThreshold = 200;

  static const Duration _pageSwitchDuration = Duration(milliseconds: 180);

  late final MediaController _controller =
      widget.controller ?? MediaController();

  bool get _ownsController => widget.controller == null;

  @override
  void initState() {
    super.initState();
    _controller.start();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final libraryAction = _controller.openLibraryAction;
        final isOffline =
            _controller.connection == MediaConnectionStatus.offline;

        return Column(
          children: [
            if (isOffline) MediaConnectionBanner(onRetry: _controller.retryNow),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: _handleSwipe,
                child: AnimatedSwitcher(
                  duration: _pageSwitchDuration,
                  child: switch (libraryAction) {
                    null => PlayerPage(
                        key: const ValueKey('media-player'),
                        controller: _controller),
                    MediaLibraryAction.create => PlaylistCreatePage(
                        key: const ValueKey('media-create'),
                        playlists: _controller.playlists,
                        onBack: _controller.closeLibraryAction,
                        onCreated: () => _controller
                            .showLibraryAction(MediaLibraryAction.collections),
                      ),
                    MediaLibraryAction.collections => CollectionsPage(
                        key: const ValueKey('media-collections'),
                        controller: _controller,
                        library: _controller.library,
                        player: _controller.player,
                        playlists: _controller.playlists,
                        onBack: _controller.closeLibraryAction,
                      ),
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Swiping right-to-left opens the queue sidebar, left-to-right closes it.
  /// Only meaningful on the player page - the collections/create pages don't
  /// have a queue sidebar to toggle.
  void _handleSwipe(DragEndDetails details) {
    if (_controller.openLibraryAction != null) {
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -_swipeVelocityThreshold && !_controller.isQueueExpanded) {
      _controller.toggleQueueExpanded();
    } else if (velocity > _swipeVelocityThreshold &&
        _controller.isQueueExpanded) {
      _controller.toggleQueueExpanded();
    }
  }
}
