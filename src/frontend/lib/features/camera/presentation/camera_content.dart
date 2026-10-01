import 'package:carnine_frontend/features/camera/data/camera_settings_store.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:video_grabber/video_grabber.dart';

typedef GrabberSourceFactory = GrabberSource Function(GrabberConfig config);

/// The camera page: the reversing camera's picture, with the settings the
/// backend keeps. The source exists only while the page is shown, so leaving
/// the page closes the device and stops the capture.
class CameraContent extends StatefulWidget {
  const CameraContent({this.settingsStore, this.sourceFactory, super.key});

  /// Without a store (tests, no backend) the grabber's defaults apply.
  final CameraSettingsStore? settingsStore;

  /// Builds the picture source; the native grabber unless a test gives one.
  final GrabberSourceFactory? sourceFactory;

  static GrabberSource nativeSource(GrabberConfig config) =>
      NativeGrabberSource(config: config);

  /// The hint over the picture while it does not play, in the UI language.
  static String messageFor(AppLocalizations l10n, GrabberState state) =>
      switch (state.status) {
        GrabberStatus.connecting => l10n.text(AppTextKey.cameraConnecting),
        GrabberStatus.playing => '',
        GrabberStatus.noSignal => l10n.text(AppTextKey.cameraNoSignal),
        GrabberStatus.deviceMissing => l10n.text(AppTextKey.cameraMissing),
        GrabberStatus.error => l10n.text(AppTextKey.cameraError),
      };

  @override
  State<CameraContent> createState() => _CameraContentState();
}

class _CameraContentState extends State<CameraContent> {
  static final Logger _logger = Logger('CameraContent');

  GrabberSource? _source;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    var config = const GrabberConfig();
    final store = widget.settingsStore;
    if (store != null) {
      try {
        config = await store.loadCameraSettings();
      } on Object catch (error) {
        // The picture matters more than the settings: show it with the
        // defaults rather than nothing.
        _logger.warning(
          'Camera settings not available, using the defaults: $error',
        );
      }
    }
    if (_disposed) {
      return;
    }
    _logger.info('Opening camera $config');
    final source = (widget.sourceFactory ?? CameraContent.nativeSource)(config);
    setState(() => _source = source);
    if (_source == source) {
      await source.start();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final source = _source;
    _source = null;
    if (source != null) {
      source.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final source = _source;
    if (source == null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            l10n.text(AppTextKey.cameraConnecting),
            key: const ValueKey('camera-loading'),
            style: const TextStyle(color: Colors.white70, fontSize: 28),
          ),
        ),
      );
    }
    return GrabberView(
      source: source,
      messageBuilder: (state) => CameraContent.messageFor(l10n, state),
    );
  }
}
