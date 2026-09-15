import 'dart:async';

import 'package:carnine_frontend/features/media/domain/media_backend_exception.dart';
import 'package:carnine_frontend/features/media/domain/media_repository.dart';
import 'package:carnine_frontend/features/media/domain/models/audio_event.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Presentation controller for system audio: volume and the transient
/// banner shown for [AudioEventKind.error]/[AudioEventKind.deviceChanged].
///
/// Every other [AudioEventKind] is internal engine lifecycle detail (source
/// started/paused/resumed/stopped, decoder stopped, ready) and stays out of
/// the UI entirely - a driver must never be shown play-engine internals
/// (`docs/02-constraints.md`: "Keine Features, die den Fahrer ablenken").
class AudioController extends ChangeNotifier {
  AudioController({
    required this._repository,
    this._onStreamFailure,
    Logger? logger,
  }) : _logger = logger ?? Logger('AudioController');

  static const _bannerDuration = Duration(seconds: 4);

  final MediaRepository _repository;
  final void Function(Object error)? _onStreamFailure;
  final Logger _logger;

  int _volumePercent = 100;
  int _volumeBeforeMute = 100;
  AppTextKey? _bannerKey;

  StreamSubscription<AudioEvent>? _subscription;
  Timer? _bannerTimer;

  int get volumePercent => _volumePercent;
  bool get isMuted => _volumePercent == 0;
  AppTextKey? get bannerKey => _bannerKey;

  /// Subscribes to the audio event stream and loads the current volume.
  /// Safe to call again after [reconnect] tore the previous subscription
  /// down.
  Future<void> start() async {
    await _subscription?.cancel();
    _subscription = _repository.audioEvents().listen(
      _onEvent,
      onError: _onStreamError,
    );
    await _loadVolume();
  }

  Future<void> reconnect() => start();

  @override
  void dispose() {
    _subscription?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVolume() async {
    try {
      final percent = await _repository.getVolume();
      _volumePercent = percent;
      if (percent > 0) {
        _volumeBeforeMute = percent;
      }
      notifyListeners();
    } on MediaBackendException catch (error) {
      _logger.warning('GetVolume failed: ${error.message}');
      if (error.kind == MediaErrorKind.offline) {
        _onStreamFailure?.call(error);
      }
    }
  }

  /// Applies [percent] immediately in the UI, then confirms with the
  /// backend. A dragged slider calls this many times a second - each call
  /// supersedes the last, only the final settled value matters.
  Future<void> setVolume(int percent) async {
    final clamped = percent.clamp(0, 100);
    _volumePercent = clamped;
    if (clamped > 0) {
      _volumeBeforeMute = clamped;
    }
    notifyListeners();

    try {
      _volumePercent = await _repository.setVolume(clamped);
    } on MediaBackendException catch (error) {
      _logger.warning('SetVolume($clamped) failed: ${error.message}');
      if (error.kind == MediaErrorKind.offline) {
        _onStreamFailure?.call(error);
      }
    } finally {
      notifyListeners();
    }
  }

  Future<void> toggleMute() async {
    if (isMuted) {
      await setVolume(_volumeBeforeMute == 0 ? 100 : _volumeBeforeMute);
    } else {
      _volumeBeforeMute = _volumePercent;
      await setVolume(0);
    }
  }

  void dismissBanner() {
    if (_bannerKey == null) {
      return;
    }
    _bannerTimer?.cancel();
    _bannerKey = null;
    notifyListeners();
  }

  void _onEvent(AudioEvent event) {
    final key = switch (event.kind) {
      AudioEventKind.error => AppTextKey.mediaAudioErrorBanner,
      AudioEventKind.deviceChanged => AppTextKey.mediaAudioDeviceChangedBanner,
      _ => null,
    };
    if (key == null) {
      return;
    }

    _logger.info('Audio event: ${event.kind} (${event.message})');
    _bannerKey = key;
    notifyListeners();
    _bannerTimer?.cancel();
    _bannerTimer = Timer(_bannerDuration, dismissBanner);
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    _logger.warning('Audio event stream failed', error, stackTrace);
    _onStreamFailure?.call(error);
  }
}
