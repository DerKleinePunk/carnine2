import 'package:carnine_frontend/features/settings/presentation/models/settings_option_item.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Presentation controller for options navigation and diagnostics events.
class SettingsController extends ChangeNotifier {
  SettingsController({SettingsSection? initialSection, Logger? logger})
    : _openSection = initialSection,
      _logger = logger ?? Logger('SettingsController');

  final Logger _logger;
  SettingsSection? _openSection;
  SettingsDevicePage? _openDevicePage;
  bool _expertsOpen = false;

  SettingsSection? get openSection => _openSection;

  /// The page open below "Geräte", `null` while its list is shown.
  SettingsDevicePage? get openDevicePage => _openDevicePage;

  /// "System → Experten" is open (#207); only after the exit password.
  bool get expertsOpen => _expertsOpen;

  void showSection(SettingsSection section) {
    if (section == _openSection) {
      return;
    }

    _logger.info('Opening settings page ${section.name}');

    _openSection = section;
    _openDevicePage = null;
    _expertsOpen = false;
    notifyListeners();
  }

  void showExperts() {
    if (_expertsOpen) {
      return;
    }

    _logger.info('Opening the expert page');

    _expertsOpen = true;
    notifyListeners();
  }

  /// Back from the expert page to "System".
  void closeExperts() {
    if (!_expertsOpen) {
      return;
    }

    _logger.info('Returning from the expert page');

    _expertsOpen = false;
    notifyListeners();
  }

  void showDevicePage(SettingsDevicePage page) {
    if (page == _openDevicePage) {
      return;
    }

    _logger.info('Opening devices page ${page.name}');

    _openDevicePage = page;
    notifyListeners();
  }

  /// Back from a device page to the "Geräte" list.
  void closeDevicePage() {
    if (_openDevicePage == null) {
      return;
    }

    _logger.info('Returning from devices page ${_openDevicePage?.name}');

    _openDevicePage = null;
    notifyListeners();
  }

  void closeSection() {
    final currentSection = _openSection;
    if (currentSection == null) {
      return;
    }

    _logger.info('Returning from settings page ${currentSection.name}');

    _openSection = null;
    _openDevicePage = null;
    _expertsOpen = false;
    notifyListeners();
  }

  void openDiagnosticsLogViewer() {
    _logger.info('Opening diagnostics log viewer');
  }
}
