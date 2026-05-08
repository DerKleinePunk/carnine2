import 'package:carnine_frontend/core/logging/app_logging.dart';
import 'package:carnine_frontend/core/logging/log_viewer_dialog.dart';
import 'package:carnine_frontend/features/settings/presentation/models/settings_option_item.dart';
import 'package:carnine_frontend/features/settings/presentation/settings_controller.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/language_flag.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_language_option.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Options screen with tile-driven subpages.
class SettingsContent extends StatefulWidget {
  const SettingsContent({
    required this.languageController,
    this.controller,
    this.logLines,
    super.key,
  });

  final AppLanguageController languageController;
  final SettingsController? controller;
  final ValueListenable<List<String>>? logLines;

  @override
  State<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<SettingsContent> {
  late final SettingsController _controller =
      widget.controller ?? SettingsController();

  bool get _ownsController => widget.controller == null;
  ValueListenable<List<String>> get _logLines =>
      widget.logLines ?? AppLogging.lines;

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return AnimatedBuilder(
          animation: widget.languageController,
          builder: (context, child) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: AnimatedSwitcher(
                duration: _SettingsMotion.duration,
                child: _buildActiveView(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveView() {
    final openSection = _controller.openSection;
    if (openSection == null) {
      return _SettingsOverview(
        key: const ValueKey<String>('settings-overview'),
        items: _options,
        onOpenSection: _controller.showSection,
      );
    }

    return _SettingsSectionPage(
      key: ValueKey<SettingsSection>(openSection),
      item: _optionFor(openSection),
      languageController: widget.languageController,
      logLines: _logLines,
      onBack: _controller.closeSection,
      onOpenLogs: _openLogViewer,
    );
  }

  void _openLogViewer() {
    _controller.openDiagnosticsLogViewer();
    showDialog<void>(
      context: context,
      builder: (context) => LogViewerDialog(logLines: _logLines),
    );
  }
}

const List<SettingsOptionItem> _options = <SettingsOptionItem>[
  SettingsOptionItem(
    section: SettingsSection.maps,
    icon: Icons.map,
    titleKey: AppTextKey.settingsMapTitle,
    subtitleKey: AppTextKey.settingsMapSubtitle,
    semanticLabelKey: AppTextKey.settingsMapSemantic,
  ),
  SettingsOptionItem(
    section: SettingsSection.appearance,
    icon: Icons.palette,
    titleKey: AppTextKey.settingsAppearanceTitle,
    subtitleKey: AppTextKey.settingsAppearanceSubtitle,
    semanticLabelKey: AppTextKey.settingsAppearanceSemantic,
  ),
  SettingsOptionItem(
    section: SettingsSection.language,
    icon: Icons.language,
    titleKey: AppTextKey.settingsLanguageTitle,
    subtitleKey: AppTextKey.settingsLanguageSubtitle,
    semanticLabelKey: AppTextKey.settingsLanguageSemantic,
  ),
  SettingsOptionItem(
    section: SettingsSection.diagnostics,
    icon: Icons.manage_search,
    titleKey: AppTextKey.settingsDiagnosticsTitle,
    subtitleKey: AppTextKey.settingsDiagnosticsSubtitle,
    semanticLabelKey: AppTextKey.settingsDiagnosticsSemantic,
  ),
];

SettingsOptionItem _optionFor(SettingsSection section) {
  return _options.firstWhere((item) => item.section == section);
}

class _SettingsOverview extends StatelessWidget {
  const _SettingsOverview({
    required this.items,
    required this.onOpenSection,
    super.key,
  });

  final List<SettingsOptionItem> items;
  final ValueChanged<SettingsSection> onOpenSection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _SettingsTileGrid(
            items: items,
            onOpenSection: onOpenSection,
          ),
        ),
      ],
    );
  }
}

class _SettingsTileGrid extends StatelessWidget {
  const _SettingsTileGrid({
    required this.items,
    required this.onOpenSection,
  });

  static const int _columns = 2;
  static const double _gap = 16;

  final List<SettingsOptionItem> items;
  final ValueChanged<SettingsSection> onOpenSection;

  @override
  Widget build(BuildContext context) {
    final rows = _chunkedRows();

    return Column(
      children: [
        for (final row in rows.indexed) ...[
          Expanded(child: _SettingsTileRow(row: row.$2, onTap: onOpenSection)),
          if (row.$1 < rows.length - 1) const SizedBox(height: _gap),
        ],
      ],
    );
  }

  List<List<SettingsOptionItem>> _chunkedRows() {
    final rows = <List<SettingsOptionItem>>[];
    for (var index = 0; index < items.length; index += _columns) {
      final end =
          index + _columns > items.length ? items.length : index + _columns;
      rows.add(items.sublist(index, end));
    }

    return rows;
  }
}

class _SettingsTileRow extends StatelessWidget {
  const _SettingsTileRow({
    required this.row,
    required this.onTap,
  });

  final List<SettingsOptionItem> row;
  final ValueChanged<SettingsSection> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in row.indexed) ...[
          Expanded(
            child: _SettingsOptionTile(
              item: entry.$2,
              onTap: () => onTap(entry.$2.section),
            ),
          ),
          if (entry.$1 < row.length - 1)
            const SizedBox(width: _SettingsTileGrid._gap),
        ],
      ],
    );
  }
}

class _SettingsOptionTile extends StatelessWidget {
  const _SettingsOptionTile({
    required this.item,
    required this.onTap,
  });

  final SettingsOptionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accentColor = _accentColor(item.section);

    return Semantics(
      button: true,
      label: l10n.text(item.semanticLabelKey),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: _softGlowColor(item.section),
          highlightColor: AppColors.surfaceContainerHigh,
          child: DecoratedBox(
            decoration: _tileDecoration(item.section),
            child: Stack(
              children: [
                Positioned.fill(child: _TileAccent(accentColor)),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: _SettingsOptionTileContent(
                    item: item,
                    accentColor: accentColor,
                    l10n: l10n,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileAccent extends StatelessWidget {
  const _TileAccent(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(8),
          ),
          boxShadow: [BoxShadow(color: color, blurRadius: 18)],
        ),
      ),
    );
  }
}

class _SettingsOptionTileContent extends StatelessWidget {
  const _SettingsOptionTileContent({
    required this.item,
    required this.accentColor,
    required this.l10n,
  });

  final SettingsOptionItem item;
  final Color accentColor;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsOptionTileTop(item: item, accentColor: accentColor),
        const Spacer(),
        Text(
          l10n.text(item.titleKey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.headlineLarge.copyWith(
            color: accentColor,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.text(item.subtitleKey),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SettingsOptionTileTop extends StatelessWidget {
  const _SettingsOptionTileTop({
    required this.item,
    required this.accentColor,
  });

  final SettingsOptionItem item;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(item.icon, color: accentColor, size: 36),
        Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant, size: 30),
      ],
    );
  }
}

class _SettingsSectionPage extends StatelessWidget {
  const _SettingsSectionPage({
    required this.item,
    required this.languageController,
    required this.logLines,
    required this.onBack,
    required this.onOpenLogs,
    super.key,
  });

  final SettingsOptionItem item;
  final AppLanguageController languageController;
  final ValueListenable<List<String>> logLines;
  final VoidCallback onBack;
  final VoidCallback onOpenLogs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsPageHeader(item: item, onBack: onBack),
        const SizedBox(height: 18),
        Expanded(child: _SettingsPageBody(child: _bodyForSection())),
      ],
    );
  }

  Widget _bodyForSection() {
    return switch (item.section) {
      SettingsSection.language => _LanguagePage(
          languageController: languageController,
        ),
      SettingsSection.diagnostics => _DiagnosticsPage(
          logLines: logLines,
          onOpenLogs: onOpenLogs,
        ),
      SettingsSection.appearance => const _PlannedPage(
          icon: Icons.palette,
          titleKey: AppTextKey.settingsAppearanceComingSoonTitle,
          bodyKey: AppTextKey.settingsAppearanceComingSoonDescription,
        ),
      SettingsSection.maps => const _PlannedPage(
          icon: Icons.map,
          titleKey: AppTextKey.settingsMapComingSoonTitle,
          bodyKey: AppTextKey.settingsMapComingSoonDescription,
        ),
    };
  }
}

class _SettingsPageHeader extends StatelessWidget {
  const _SettingsPageHeader({
    required this.item,
    required this.onBack,
  });

  final SettingsOptionItem item;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accentColor = _accentColor(item.section);

    return Row(
      children: [
        _BackButton(onBack: onBack, l10n: l10n),
        const SizedBox(width: 16),
        Icon(item.icon, color: accentColor, size: 32),
        const SizedBox(width: 14),
        Expanded(child: _SettingsPageTitle(item: item, l10n: l10n)),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({
    required this.onBack,
    required this.l10n,
  });

  final VoidCallback onBack;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: l10n.text(AppTextKey.settingsBackToOptions),
      child: SizedBox(
        width: 56,
        height: 56,
        child: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 26),
          color: AppColors.primary,
          tooltip: l10n.text(AppTextKey.settingsBackToOptions),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceContainerHighest,
            side: const BorderSide(color: AppColors.primary20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsPageTitle extends StatelessWidget {
  const _SettingsPageTitle({
    required this.item,
    required this.l10n,
  });

  final SettingsOptionItem item;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.text(item.titleKey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.headlineLarge.copyWith(
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.text(item.subtitleKey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SettingsPageBody extends StatelessWidget {
  const _SettingsPageBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant20),
        boxShadow: const [
          BoxShadow(color: AppColors.primary20, blurRadius: 18),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: child,
      ),
    );
  }
}

class _LanguagePage extends StatelessWidget {
  const _LanguagePage({required this.languageController});

  final AppLanguageController languageController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedOption = AppLanguageOptions.byLocale(
      languageController.locale,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: l10n.text(AppTextKey.settingsCurrentLanguage)),
        const SizedBox(height: 12),
        _SelectedLanguageDisplay(option: selectedOption, l10n: l10n),
        const SizedBox(height: 22),
        Expanded(
          child: _LanguageGrid(
            languageController: languageController,
            selectedOption: selectedOption,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelLarge.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SelectedLanguageDisplay extends StatelessWidget {
  const _SelectedLanguageDisplay({
    required this.option,
    required this.l10n,
  });

  final AppLanguageOption option;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            LanguageFlag(flag: option.flag),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                l10n.text(option.labelKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.headlineLarge.copyWith(
                  color: AppColors.onSurface,
                  fontSize: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageGrid extends StatelessWidget {
  const _LanguageGrid({
    required this.languageController,
    required this.selectedOption,
  });

  final AppLanguageController languageController;
  final AppLanguageOption selectedOption;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 620 ? 2 : 3;
        final options = _sortedLanguageOptions(l10n);

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: crossAxisCount == 2 ? 2.75 : 3.3,
          ),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            final isSelected = option.locale.languageCode ==
                selectedOption.locale.languageCode;

            return _LanguageOptionTile(
              option: option,
              l10n: l10n,
              isSelected: isSelected,
              onTap: () => languageController.setLocale(option.locale),
            );
          },
        );
      },
    );
  }

  List<AppLanguageOption> _sortedLanguageOptions(AppLocalizations l10n) {
    return <AppLanguageOption>[...AppLanguageOptions.all]..sort(
        (left, right) => l10n
            .text(left.labelKey)
            .toLowerCase()
            .compareTo(l10n.text(right.labelKey).toLowerCase()),
      );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.option,
    required this.l10n,
    required this.isSelected,
    required this.onTap,
  });

  final AppLanguageOption option;
  final AppLocalizations l10n;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: l10n.text(option.labelKey),
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: AppColors.primary20,
          highlightColor: AppColors.surfaceContainerHigh,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.surfaceContainerHighest
                  : AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.primary20,
              ),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: AppColors.primary20,
                        blurRadius: 18,
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  LanguageFlag(flag: option.flag),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.text(option.labelKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
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

class _DiagnosticsPage extends StatelessWidget {
  const _DiagnosticsPage({
    required this.logLines,
    required this.onOpenLogs,
  });

  final ValueListenable<List<String>> logLines;
  final VoidCallback onOpenLogs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
            text: l10n.text(AppTextKey.settingsDiagnosticsRecentLogs)),
        const SizedBox(height: 12),
        Expanded(child: _InlineLogPanel(logLines: logLines)),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: onOpenLogs,
            icon: const Icon(Icons.article, size: 22),
            label: Text(l10n.text(AppTextKey.settingsDiagnosticsOpenLogs)),
          ),
        ),
      ],
    );
  }
}

class _InlineLogPanel extends StatelessWidget {
  const _InlineLogPanel({required this.logLines});

  final ValueListenable<List<String>> logLines;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: ValueListenableBuilder<List<String>>(
          valueListenable: logLines,
          builder: (context, logs, child) => _InlineLogList(logs: logs),
        ),
      ),
    );
  }
}

class _InlineLogList extends StatelessWidget {
  const _InlineLogList({required this.logs});

  final List<String> logs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (logs.isEmpty) {
      return Center(
        child: Text(
          l10n.text(AppTextKey.noLogEntriesYet),
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
    }

    return _VisibleLogList(logs: logs);
  }
}

class _VisibleLogList extends StatelessWidget {
  const _VisibleLogList({required this.logs});

  final List<String> logs;

  @override
  Widget build(BuildContext context) {
    final visibleLogs =
        logs.length > 30 ? logs.sublist(logs.length - 30) : logs;

    return ListView.builder(
      itemCount: visibleLogs.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            visibleLogs[index],
            style: AppTextStyles.logLine.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}

class _PlannedPage extends StatelessWidget {
  const _PlannedPage({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
  });

  final IconData icon;
  final AppTextKey titleKey;
  final AppTextKey bodyKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant, size: 54),
          const SizedBox(height: 18),
          Text(
            l10n.text(titleKey),
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.onSurface,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.text(bodyKey),
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

BoxDecoration _tileDecoration(SettingsSection section) {
  return BoxDecoration(
    color: AppColors.surfaceContainer,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: _accentColor(section)),
    boxShadow: [
      BoxShadow(
        color: _softGlowColor(section),
        blurRadius: 34,
        spreadRadius: -10,
      ),
      BoxShadow(
        color: _strongGlowColor(section),
        blurRadius: 16,
        spreadRadius: -12,
      ),
    ],
  );
}

Color _accentColor(SettingsSection section) {
  return switch (section) {
    SettingsSection.language => AppColors.primary,
    SettingsSection.diagnostics => AppColors.primary,
    SettingsSection.appearance => AppColors.secondary,
    SettingsSection.maps => AppColors.tertiary,
  };
}

Color _softGlowColor(SettingsSection section) {
  return switch (section) {
    SettingsSection.language => AppColors.primary20,
    SettingsSection.diagnostics => AppColors.primary20,
    SettingsSection.appearance => AppColors.secondary20,
    SettingsSection.maps => AppColors.tertiary20,
  };
}

Color _strongGlowColor(SettingsSection section) {
  return switch (section) {
    SettingsSection.language => AppColors.primary40,
    SettingsSection.diagnostics => AppColors.primary40,
    SettingsSection.appearance => AppColors.secondary40,
    SettingsSection.maps => AppColors.tertiary40,
  };
}

abstract final class _SettingsMotion {
  const _SettingsMotion._();

  static const Duration duration = Duration(milliseconds: 180);
}
