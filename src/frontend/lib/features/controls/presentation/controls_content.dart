import 'dart:async';

import 'package:carnine_frontend/features/controls/data/controls_repository.dart';
import 'package:carnine_frontend/features/controls/domain/control.dart';
import 'package:carnine_frontend/features/controls/presentation/controls_controller.dart';
import 'package:carnine_frontend/features/controls/presentation/widgets/control_slider_card.dart';
import 'package:carnine_frontend/features/controls/presentation/widgets/control_switch_card.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// The Technik page (#86): the switches and sliders the backend lists, as
/// cards in four columns. Eight switches are two rows, so they fit on the
/// 1024 x 600 panel without scrolling; a slider takes a low row of its own
/// across the whole page, and more controls scroll.
///
/// Built only while the page is shown: leaving it closes the stream.
class ControlsContent extends StatefulWidget {
  const ControlsContent({this.repository, super.key});

  /// Without one (tests, no backend) there are no controls to show.
  final ControlsRepository? repository;

  @override
  State<ControlsContent> createState() => _ControlsContentState();
}

class _ControlsContentState extends State<ControlsContent> {
  static const double _gap = 16;
  static const double _cardHeight = 176;
  static const double _sliderHeight = 112;
  static const int _columns = 4;

  late final ControlsController? _controller = _createController();

  ControlsController? _createController() {
    final repository = widget.repository;
    return repository == null
        ? null
        : ControlsController(repository: repository);
  }

  @override
  void initState() {
    super.initState();
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.start());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: controller == null
          ? const _Message(
              icon: Icons.lightbulb_outline,
              messageKey: AppTextKey.controlsEmpty,
            )
          : ListenableBuilder(
              listenable: controller,
              builder: (context, child) => switch (controller.status) {
                ControlsStatus.loading => const _Message(
                  messageKey: AppTextKey.mediaLoading,
                ),
                ControlsStatus.offline => _OfflineView(
                  onRetry: controller.retryNow,
                ),
                ControlsStatus.ready => _buildReady(controller),
              },
            ),
    );
  }

  Widget _buildReady(ControlsController controller) {
    if (controller.controls.isEmpty) {
      return const _Message(
        icon: Icons.lightbulb_outline,
        messageKey: AppTextKey.controlsEmpty,
      );
    }
    final errorKey = controller.errorKey;

    return Column(
      children: [
        if (errorKey != null) ...[
          _ErrorStrip(messageKey: errorKey, onDismiss: controller.dismissError),
          const SizedBox(height: _gap),
        ],
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final unit =
                  (constraints.maxWidth - (_columns - 1) * _gap) / _columns;
              return SingleChildScrollView(
                child: Wrap(
                  spacing: _gap,
                  runSpacing: _gap,
                  children: [
                    for (final control in controller.controls)
                      SizedBox(
                        width: control.kind == ControlKind.slider
                            ? constraints.maxWidth
                            : unit,
                        height: control.kind == ControlKind.slider
                            ? _sliderHeight
                            : _cardHeight,
                        child: _cardFor(controller, control),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cardFor(ControlsController controller, ControlDefinition control) {
    final id = control.id;
    return switch (control.kind) {
      ControlKind.toggle => ControlSwitchCard(
        key: ValueKey<String>('control-$id'),
        name: control.name,
        isOn: controller.isOn(id),
        isAvailable: controller.isAvailable(id),
        onTap: () => unawaited(controller.toggle(id)),
      ),
      ControlKind.slider => ControlSliderCard(
        key: ValueKey<String>('control-$id'),
        name: control.name,
        level: controller.levelOf(control),
        min: control.min,
        max: control.max,
        isAvailable: controller.isAvailable(id),
        onChanged: (level) => controller.dragLevel(id, level),
        onChangeEnd: (level) => unawaited(controller.commitLevel(id, level)),
      ),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.messageKey, this.icon});

  final AppTextKey messageKey;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.onSurfaceVariant, size: 54),
            const SizedBox(height: 18),
          ],
          Text(
            AppLocalizations.of(context).text(messageKey),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineView extends StatelessWidget {
  const _OfflineView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off,
            color: AppColors.onSurfaceVariant,
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            l10n.text(AppTextKey.mediaOfflineDescription),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 22),
            label: Text(l10n.text(AppTextKey.mediaRetry)),
          ),
        ],
      ),
    );
  }
}

/// A change that did not work, shown briefly above the cards; a tap closes
/// it early. No border, like the banners of the media page.
class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip({required this.messageKey, required this.onDismiss});

  final AppTextKey messageKey;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onDismiss,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).text(messageKey),
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
