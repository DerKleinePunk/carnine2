import 'package:carnine_frontend/features/settings/presentation/models/settings_option_item.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Presentation controller for options navigation and diagnostics events.
class SettingsController extends ChangeNotifier {
  SettingsController({
    SettingsSection? initialSection,
    Logger? logger,
  })  : _openSection = initialSection,
        _logger = logger ?? Logger('SettingsController');

  final Logger _logger;
  SettingsSection? _openSection;

  SettingsSection? get openSection => _openSection;

  void showSection(SettingsSection section) {
    if (section == _openSection) {
      return;
    }

    _logger.info('Opening settings page ${section.name}');

    _openSection = section;
    notifyListeners();
  }

  void closeSection() {
    final currentSection = _openSection;
    if (currentSection == null) {
      return;
    }

    _logger.info('Returning from settings page ${currentSection.name}');

    _openSection = null;
    notifyListeners();
  }

  void openDiagnosticsLogViewer() {
    _logger.info('Opening diagnostics log viewer');
  }
}
