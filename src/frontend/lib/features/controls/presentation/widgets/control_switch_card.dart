import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// A switch of the Technik page: the whole card toggles. The little switch
/// and the text "AN" or "AUS" only show the state. On, the card glows in the
/// primary color; off, it is dimmed; without its module it is greyed out and
/// does not react.
class ControlSwitchCard extends StatelessWidget {
  const ControlSwitchCard({
    required this.name,
    required this.isOn,
    required this.isAvailable,
    required this.onTap,
    super.key,
  });

  /// What the user called it - shown as it is, not translated.
  final String name;
  final bool isOn;
  final bool isAvailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLit = isAvailable && isOn;
    final accent = !isAvailable
        ? AppColors.outline
        : (isOn ? AppColors.primary : AppColors.onSurfaceVariant);
    final stateText = l10n.text(
      !isAvailable
          ? AppTextKey.controlsUnavailable
          : (isOn ? AppTextKey.controlsStateOn : AppTextKey.controlsStateOff),
    );

    return Semantics(
      button: true,
      toggled: isOn,
      enabled: isAvailable,
      label: name,
      value: stateText,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isAvailable ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.primary20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isLit
                  ? AppColors.surfaceContainerHigh
                  : AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLit ? AppColors.primary : AppColors.outlineVariant20,
              ),
              boxShadow: isLit
                  ? const [
                      BoxShadow(
                        color: AppColors.primary20,
                        blurRadius: 30,
                        spreadRadius: -10,
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.power_settings_new, color: accent, size: 34),
                      _MiniSwitch(isOn: isOn, isAvailable: isAvailable),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: isAvailable
                          ? AppColors.onSurface
                          : AppColors.onSurfaceVariant,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stateText.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
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

/// The switch drawn on the card; it shows the state and takes no touch of
/// its own.
class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.isOn, required this.isAvailable});

  final bool isOn;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final isLit = isAvailable && isOn;

    return Container(
      width: 56,
      height: 30,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isLit ? AppColors.primary40 : AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isLit ? AppColors.primary : AppColors.outlineVariant20,
        ),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 150),
        alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: !isAvailable
                ? AppColors.outline
                : (isOn ? AppColors.primary : AppColors.onSurfaceVariant),
          ),
          child: const SizedBox(width: 20, height: 20),
        ),
      ),
    );
  }
}
