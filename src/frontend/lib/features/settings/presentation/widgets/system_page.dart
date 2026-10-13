import 'package:carnine_frontend/core/app_version.dart';
import 'package:carnine_frontend/features/settings/data/exit_password_store.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/change_exit_password_dialog.dart';
import 'package:carnine_frontend/features/settings/presentation/widgets/exit_password_dialog.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// "System": six tiles in two groups. "Wartung" holds what a technician
/// uses (logs, updates, the exit password), "Oberfläche" what concerns the
/// running interface (restart, exit, version). "Beenden" is marked in the
/// warning color: it closes the interface, and only a password gets it back.
class SystemPage extends StatelessWidget {
  const SystemPage({
    required this.exitPasswordStore,
    required this.onOpenLogs,
    required this.onRestart,
    required this.onExit,
    super.key,
  });

  /// Where the exit password is checked and changed; `null` without a
  /// backend (tests), where neither can work.
  final ExitPasswordStore? exitPasswordStore;
  final VoidCallback onOpenLogs;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  static const double _gap = 16;

  /// Fixed, so the tiles never overflow: a notice strip above the page (power
  /// supply, no audio output) takes room, and then the page scrolls.
  static const double _tileHeight = 128;

  Future<void> _showUpdatesUnavailable(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.text(AppTextKey.settingsDiagnosticsUpdatesUnavailableTitle),
        ),
        content: Text(
          l10n.text(AppTextKey.settingsDiagnosticsUpdatesUnavailableMessage),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.text(AppTextKey.close)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await ExitPasswordDialog.show(
      context,
      store: exitPasswordStore,
    );
    if (confirmed) {
      onExit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = AppVersion.buildDate;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupLabel(
            text: l10n.text(AppTextKey.settingsDiagnosticsGroupMaintenance),
          ),
          const SizedBox(height: 10),
          _TileRow(
            height: _tileHeight,
            gap: _gap,
            tiles: [
              _SystemTile(
                icon: Icons.article,
                title: l10n.text(AppTextKey.settingsDiagnosticsOpenLogs),
                subtitle: l10n.text(AppTextKey.settingsDiagnosticsLogsSubtitle),
                onTap: onOpenLogs,
              ),
              _SystemTile(
                icon: Icons.system_update,
                title: l10n.text(AppTextKey.settingsDiagnosticsCheckUpdates),
                subtitle: l10n.text(
                  AppTextKey.settingsDiagnosticsUpdatesUnavailableTitle,
                ),
                onTap: () => _showUpdatesUnavailable(context),
              ),
              _SystemTile(
                icon: Icons.password,
                title: l10n.text(AppTextKey.settingsDiagnosticsChangePassword),
                subtitle: l10n.text(
                  AppTextKey.settingsDiagnosticsChangePasswordSubtitle,
                ),
                onTap: () => ChangeExitPasswordDialog.show(
                  context,
                  store: exitPasswordStore,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _GroupLabel(
            text: l10n.text(AppTextKey.settingsDiagnosticsGroupInterface),
          ),
          const SizedBox(height: 10),
          _TileRow(
            height: _tileHeight,
            gap: _gap,
            tiles: [
              _SystemTile(
                icon: Icons.restart_alt,
                title: l10n.text(AppTextKey.settingsDiagnosticsRestart),
                subtitle: l10n.text(
                  AppTextKey.settingsDiagnosticsRestartSubtitle,
                ),
                onTap: onRestart,
              ),
              _SystemTile(
                icon: Icons.power_settings_new,
                title: l10n.text(AppTextKey.settingsDiagnosticsExit),
                subtitle: l10n.text(AppTextKey.settingsDiagnosticsExitSubtitle),
                isWarning: true,
                onTap: () => _confirmExit(context),
              ),
              _SystemTile(
                icon: Icons.info_outline,
                title: l10n.text(AppTextKey.settingsDiagnosticsVersion),
                subtitle: date.isEmpty
                    ? AppVersion.version
                    : '${AppVersion.version}\n$date',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text});

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

class _TileRow extends StatelessWidget {
  const _TileRow({
    required this.height,
    required this.gap,
    required this.tiles,
  });

  final double height;
  final double gap;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (final entry in tiles.indexed) ...[
            Expanded(child: entry.$2),
            if (entry.$1 < tiles.length - 1) SizedBox(width: gap),
          ],
        ],
      ),
    );
  }
}

/// One tile. Without [onTap] it only shows information and does not react.
class _SystemTile extends StatelessWidget {
  const _SystemTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isWarning = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final isActive = onTap != null;
    final accent = isWarning ? AppColors.error : AppColors.primary;

    return Semantics(
      button: isActive,
      label: '$title, ${subtitle.replaceAll('\n', ', ')}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: isWarning
              ? AppColors.errorContainer
              : AppColors.primary20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? accent : AppColors.outlineVariant20,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        icon,
                        color: isActive ? accent : AppColors.outline,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: isActive ? accent : AppColors.onSurface,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
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
