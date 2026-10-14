import 'package:carnine_frontend/features/settings/data/announcement_settings_store.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/announcements_tab.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/settings_choice_button.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// "Karteneinstellungen": two tabs. It opens on "Ansagen" (#110), the spoken
/// turn instructions; [mapTab] is what is behind "Karte" - for now a
/// placeholder, the zoom of following the car comes there (#131).
class MapSettingsPage extends StatefulWidget {
  const MapSettingsPage({
    required this.announcementSettingsStore,
    required this.mapTab,
    super.key,
  });

  final AnnouncementSettingsStore announcementSettingsStore;
  final Widget mapTab;

  @override
  State<MapSettingsPage> createState() => _MapSettingsPageState();
}

enum _MapSettingsTab { announcements, map }

class _MapSettingsPageState extends State<MapSettingsPage> {
  _MapSettingsTab _tab = _MapSettingsTab.announcements;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SettingsChoiceButton(
                icon: Icons.record_voice_over,
                label: l10n.text(AppTextKey.settingsMapTabAnnouncements),
                isSelected: _tab == _MapSettingsTab.announcements,
                onTap: () =>
                    setState(() => _tab = _MapSettingsTab.announcements),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SettingsChoiceButton(
                icon: Icons.map,
                label: l10n.text(AppTextKey.settingsMapTabMap),
                isSelected: _tab == _MapSettingsTab.map,
                onTap: () => setState(() => _tab = _MapSettingsTab.map),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: switch (_tab) {
            _MapSettingsTab.announcements => AnnouncementsTab(
              store: widget.announcementSettingsStore,
            ),
            _MapSettingsTab.map => widget.mapTab,
          },
        ),
      ],
    );
  }
}
