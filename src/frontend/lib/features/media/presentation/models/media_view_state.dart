import 'package:carnine_frontend/l10n/app_localizations.dart';

/// Coarse loading/empty/error/offline status shared by every list-based view
/// in the media feature (library results, playlists, playlist entries).
enum MediaViewStatus {
  idle,
  loading,
  ready,
  empty,
  error,
  offline,
}

/// Value type paired with `MediaStateView` to render one of the shared
/// loading/empty/error/offline states consistently across the feature.
class MediaViewState {
  const MediaViewState.idle()
      : status = MediaViewStatus.idle,
        messageKey = null;

  const MediaViewState.loading()
      : status = MediaViewStatus.loading,
        messageKey = null;

  const MediaViewState.ready()
      : status = MediaViewStatus.ready,
        messageKey = null;

  const MediaViewState.empty(AppTextKey key)
      : status = MediaViewStatus.empty,
        messageKey = key;

  const MediaViewState.error(AppTextKey key)
      : status = MediaViewStatus.error,
        messageKey = key;

  const MediaViewState.offline()
      : status = MediaViewStatus.offline,
        messageKey = null;

  final MediaViewStatus status;
  final AppTextKey? messageKey;

  bool get isReady => status == MediaViewStatus.ready;
}
