import 'dart:async';

import 'package:carnine_frontend/features/dashboard/data/ui_state_store.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';

/// Keeps the display language across restarts (#30): brings back the one
/// saved last and saves every language the user picks.
///
/// The frontend may start before the backend answers, so loading is tried
/// again with growing pauses, like the page shown last. A language the user
/// picks in the meantime wins over the one still loading.
class LanguagePersistence {
  LanguagePersistence({
    required this.controller,
    required this.store,
    this.retryDelays = const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 5),
    ],
    this.giveUpAfter = const Duration(minutes: 2),
    Logger? logger,
  }) : _logger = logger ?? Logger('LanguagePersistence');

  final AppLanguageController controller;
  final UiStateStore store;
  final List<Duration> retryDelays;
  final Duration giveUpAfter;
  final Logger _logger;

  bool _restoring = false;
  bool _userPicked = false;
  bool _disposed = false;

  void start() {
    controller.addListener(_onLanguageChanged);
    unawaited(_restore());
  }

  void dispose() {
    _disposed = true;
    controller.removeListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (_restoring) {
      return;
    }
    _userPicked = true;
    unawaited(_save(controller.locale.languageCode));
  }

  Future<void> _save(String languageCode) async {
    try {
      await store.saveLanguage(languageCode);
      _logger.info('Language $languageCode saved');
    } catch (error, stackTrace) {
      _logger.warning('Could not save the language', error, stackTrace);
    }
  }

  Future<void> _restore() async {
    final code = await _load();
    if (code == null || code.isEmpty || _userPicked || _disposed) {
      return;
    }
    _logger.info('Restoring language $code');
    _restoring = true;
    controller.setLocale(Locale(code));
    _restoring = false;
  }

  /// The saved code, or null once it gave up or the user picked one.
  Future<String?> _load() async {
    var waited = Duration.zero;
    for (var attempt = 0; ; attempt++) {
      try {
        return await store.loadLanguage();
      } on GrpcError catch (error) {
        if (error.code != StatusCode.unavailable || waited >= giveUpAfter) {
          _logger.warning('Could not restore the language: $error');
          return null;
        }
      } catch (error, stackTrace) {
        _logger.warning('Could not restore the language', error, stackTrace);
        return null;
      }
      final delay = retryDelays[attempt.clamp(0, retryDelays.length - 1)];
      waited += delay;
      await Future<void>.delayed(delay);
      if (_disposed || _userPicked) {
        return null;
      }
    }
  }
}
