import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Fixed side menu based on the 1024x600 Stitch dashboard template.
class SideMenu extends StatelessWidget {
  const SideMenu({
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    super.key,
  });

  static const double width = 96;
  static const Duration animationDuration = Duration(milliseconds: 180);

  final List<DashboardNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.primary20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary20,
            blurRadius: 30,
            offset: Offset(10, 0),
            spreadRadius: -15,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SideMenuNavigation(
            items: items,
            selectedIndex: selectedIndex,
            onItemSelected: onItemSelected,
          ),
          const _SideMenuFooter(),
        ],
      ),
    );
  }
}

class _SideMenuNavigation extends StatelessWidget {
  const _SideMenuNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  final List<DashboardNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  static const double _itemHeight = 72;
  static const double _itemInset = 4;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const _BrandHeader(),
        const SizedBox(height: 16),
        SizedBox(
          width: SideMenu.width,
          height: items.length * _itemHeight,
          child: Stack(
            children: [
              _SlidingSelection(
                top: selectedIndex * _itemHeight + _itemInset,
                height: _itemHeight - (_itemInset * 2),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in items.indexed)
                    _SideMenuTile(
                      item: entry.$2,
                      height: _itemHeight,
                      isSelected: entry.$1 == selectedIndex,
                      onTap: () => onItemSelected(entry.$1),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'CarNine',
          style: AppTextStyles.kineticBrand.copyWith(
            color: AppColors.primary,
          ),
        ),
        Text(
          'V8-ACTIVE',
          style: AppTextStyles.kineticSubtitle.copyWith(
            color: AppColors.primary40,
          ),
        ),
      ],
    );
  }
}

class _SideMenuTile extends StatelessWidget {
  const _SideMenuTile({
    required this.item,
    required this.height,
    required this.isSelected,
    required this.onTap,
  });

  final DashboardNavItem item;
  final double height;
  final bool isSelected;
  final VoidCallback onTap;

  static const double _iconSize = 22;
  static const double _labelGap = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: l10n.text(item.semanticLabelKey),
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primary20,
        highlightColor: AppColors.surfaceContainer,
        child: SizedBox(
          width: SideMenu.width,
          height: height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSlide(
                offset: isSelected ? Offset.zero : const Offset(-0.05, 0),
                duration: SideMenu.animationDuration,
                curve: Curves.easeOutCubic,
                child: Icon(item.icon, color: _contentColor, size: _iconSize),
              ),
              const SizedBox(height: _labelGap),
              AnimatedDefaultTextStyle(
                duration: SideMenu.animationDuration,
                curve: Curves.easeOutCubic,
                style: AppTextStyles.navItem.copyWith(color: _contentColor),
                child: Text(l10n.text(item.labelKey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _contentColor {
    return isSelected ? AppColors.primary : AppColors.onSurfaceVariant;
  }
}

class _SlidingSelection extends StatelessWidget {
  const _SlidingSelection({
    required this.top,
    required this.height,
  });

  final double top;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      top: top,
      left: 0,
      right: 0,
      height: height,
      duration: SideMenu.animationDuration,
      curve: Curves.easeOutCubic,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          border: Border(
            left: BorderSide(color: AppColors.primary, width: 4),
          ),
          boxShadow: [
            BoxShadow(color: AppColors.primary40, blurRadius: 15),
          ],
        ),
      ),
    );
  }
}

class _SideMenuFooter extends StatelessWidget {
  const _SideMenuFooter();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _EmergencyButton(),
        SizedBox(height: 16),
      ],
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  const _EmergencyButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.errorContainer,
        foregroundColor: AppColors.onErrorContainer,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        textStyle: AppTextStyles.emergencyButton,
      ),
      child: Text(l10n.text(AppTextKey.emergency)),
    );
  }
}
