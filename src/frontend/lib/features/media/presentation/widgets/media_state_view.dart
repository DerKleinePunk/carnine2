import 'package:carnine_frontend/features/media/presentation/models/media_view_state.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Renders the shared loading/empty/error/offline states consistently
/// across every list in the media feature, or [builder]'s content once
/// [state] is ready.
///
/// Non-blocking by design: callers only pass a [MediaViewState.loading]
/// state on the *first* load (when there is nothing to show yet) - a
/// background refresh keeps the previous content visible via [builder]
/// instead of routing through this widget.
class MediaStateView extends StatelessWidget {
  const MediaStateView({
    required this.state,
    required this.builder,
    this.onRetry,
    super.key,
  });

  final MediaViewState state;
  final WidgetBuilder builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return switch (state.status) {
      MediaViewStatus.idle || MediaViewStatus.ready => builder(context),
      MediaViewStatus.loading => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                l10n.text(AppTextKey.mediaLoading),
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      MediaViewStatus.empty => _MessageState(
          icon: Icons.library_music,
          iconColor: AppColors.onSurfaceVariant,
          message: l10n.text(state.messageKey!),
        ),
      MediaViewStatus.error => _MessageState(
          icon: Icons.error_outline,
          iconColor: AppColors.error,
          message: l10n.text(
              state.messageKey ?? AppTextKey.mediaBackendErrorDescription),
          onRetry: onRetry,
        ),
      MediaViewStatus.offline => _MessageState(
          icon: Icons.cloud_off,
          iconColor: AppColors.error,
          message: l10n.text(AppTextKey.mediaOfflineDescription),
          onRetry: onRetry,
        ),
    };
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final Color iconColor;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // A tight or heavily text-scaled container (e.g. the queue sidebar's
    // empty state) can be shorter than this message's natural height -
    // scroll instead of overflowing rather than forcing a taller container.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: _content(context)),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 48),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          _RetryButton(onTap: onRetry!),
        ],
      ],
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = l10n.text(AppTextKey.mediaRetry);

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          splashColor: AppColors.primary20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.primary20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
