import 'dart:async';

import 'package:carnine_frontend/features/camera/data/camera_settings_store.dart';
import 'package:carnine_frontend/features/camera/domain/video_device.dart';
import 'package:carnine_frontend/features/camera/presentation/camera_settings_controller.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/settings_choice_button.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:video_grabber/video_grabber.dart';

/// Camera settings (#79): device on the left, norm, input and width of the
/// grabber on the right. Every tap saves at once. The camera page reads the
/// settings when it opens, so [onShowCamera] jumps there to see the result.
class CameraSettingsPage extends StatefulWidget {
  const CameraSettingsPage({
    required this.store,
    required this.onShowCamera,
    super.key,
  });

  final CameraSettingsStore store;
  final VoidCallback onShowCamera;

  @override
  State<CameraSettingsPage> createState() => _CameraSettingsPageState();
}

class _CameraSettingsPageState extends State<CameraSettingsPage> {
  late final CameraSettingsController _controller = CameraSettingsController(
    store: widget.store,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) => switch (_controller.status) {
        CameraSettingsStatus.loading => const _CenteredMessage(
          messageKey: AppTextKey.mediaLoading,
        ),
        CameraSettingsStatus.offline => _OfflineView(onRetry: _controller.load),
        CameraSettingsStatus.ready => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _DeviceColumn(
                controller: _controller,
                onShowCamera: widget.onShowCamera,
              ),
            ),
            const SizedBox(width: 22),
            Expanded(flex: 6, child: _GrabberColumn(controller: _controller)),
          ],
        ),
      },
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.messageKey});

  final AppTextKey messageKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(context).text(messageKey),
        style: AppTextStyles.bodyLarge.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.labelLarge.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DeviceColumn extends StatelessWidget {
  const _DeviceColumn({required this.controller, required this.onShowCamera});

  final CameraSettingsController controller;
  final VoidCallback onShowCamera;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final errorKey = controller.errorKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(l10n.text(AppTextKey.settingsCameraDeviceLabel)),
        const SizedBox(height: 12),
        Expanded(child: _DeviceList(controller: controller)),
        const SizedBox(height: 12),
        if (errorKey != null) ...[
          Text(
            l10n.text(errorKey),
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.error,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          l10n.text(AppTextKey.settingsCameraAppliesNote),
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onShowCamera,
            icon: const Icon(Icons.videocam, size: 22),
            label: Text(l10n.text(AppTextKey.settingsCameraShowAction)),
          ),
        ),
      ],
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.controller});

  static const String _stableNamePrefix = '/dev/v4l/';

  final CameraSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = controller.config;
    // The saved device stays in the list even when it is not plugged in.
    final missingPath = controller.isSelectedDeviceMissing
        ? config?.device
        : null;

    final rows = <Widget>[
      // An empty list says so, and still shows the saved device below.
      if (controller.devices.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            l10n.text(AppTextKey.settingsCameraNoDevices),
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      if (missingPath != null)
        _DeviceChoice(
          title: missingPath,
          // A fixed name under /dev/v4l/ is a link to whatever node the
          // camera has now, and the list only holds /dev/video<n>: it may be
          // plugged in, so the page does not claim it is not.
          subtitle: missingPath.startsWith(_stableNamePrefix)
              ? ''
              : l10n.text(AppTextKey.cameraMissing),
          isSelected: true,
          isEnabled: false,
          onTap: () {},
        ),
      for (final device in controller.devices)
        _DeviceChoice(
          title: device.name.isEmpty ? device.path : device.name,
          subtitle: _subtitleFor(device),
          isSelected: device.path == config?.device,
          isEnabled: !controller.isSaving,
          onTap: () => unawaited(controller.selectDevice(device.path)),
        ),
    ];

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => rows[index],
    );
  }

  static String _subtitleFor(VideoDevice device) {
    return device.name.isEmpty || device.name == device.path ? '' : device.path;
  }
}

class _DeviceChoice extends StatelessWidget {
  const _DeviceChoice({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: isEnabled,
      label: subtitle.isEmpty ? title : '$title, $subtitle',
      excludeSemantics: true,
      child: Material(
        color: isSelected
            ? AppColors.surfaceContainerHighest
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          splashColor: AppColors.primary20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.outlineVariant20,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: color,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                      ],
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

class _GrabberColumn extends StatelessWidget {
  const _GrabberColumn({required this.controller});

  /// Input values the STK1160 knows: 0 to 3 are Composite, 4 is S-Video.
  /// The backend allows more; a saved value outside this range is shown as
  /// one more button, so it is neither lost nor hidden.
  static const List<int> _inputs = [0, 1, 2, 3, 4];
  static const int _sVideoInput = 4;

  final CameraSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = controller.config;
    if (config == null) {
      return const SizedBox.shrink();
    }
    final isEnabled =
        controller.areGrabberFieldsEnabled && !controller.isSaving;
    final normLabel = l10n.text(AppTextKey.settingsCameraNormLabel);
    final inputLabel = l10n.text(AppTextKey.settingsCameraInputLabel);
    final widthLabel = l10n.text(AppTextKey.settingsCameraWidthLabel);
    final inputs = _inputs.contains(config.input)
        ? _inputs
        : [..._inputs, config.input];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(normLabel),
          const SizedBox(height: 8),
          _ChoiceRow(
            children: [
              for (final norm in VideoNorm.values.reversed)
                SettingsChoiceButton(
                  label: norm.name.toUpperCase(),
                  semanticLabel: '$normLabel ${norm.name.toUpperCase()}',
                  isSelected: config.norm == norm,
                  isEnabled: isEnabled,
                  onTap: () => unawaited(controller.selectNorm(norm)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldLabel(inputLabel),
          const SizedBox(height: 8),
          _ChoiceRow(
            children: [
              for (final input in inputs)
                SettingsChoiceButton(
                  label: input == _sVideoInput
                      ? l10n.text(AppTextKey.settingsCameraInputSVideo)
                      : '$input',
                  semanticLabel:
                      '$inputLabel ${input == _sVideoInput ? l10n.text(AppTextKey.settingsCameraInputSVideo) : input}',
                  isSelected: config.input == input,
                  isEnabled: isEnabled,
                  onTap: () => unawaited(controller.selectInput(input)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldLabel(widthLabel),
          const SizedBox(height: 8),
          _ChoiceRow(
            children: [
              for (final width in const [360, 720])
                SettingsChoiceButton(
                  label: '$width',
                  semanticLabel: '$widthLabel $width',
                  isSelected: config.width == width,
                  isEnabled: isEnabled,
                  onTap: () => unawaited(controller.selectWidth(width)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.text(
              controller.areGrabberFieldsEnabled
                  ? AppTextKey.settingsCameraWidthHint
                  : AppTextKey.settingsCameraAnalogOnlyNote,
            ),
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in children.indexed) ...[
          Expanded(child: entry.$2),
          if (entry.$1 < children.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
