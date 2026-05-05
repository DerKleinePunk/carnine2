import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
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

  final List<DashboardNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: AppColors.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        const _BrandHeader(),
        const SizedBox(height: 16),
        for (final entry in items.indexed)
          _SideMenuTile(
            item: entry.$2,
            isSelected: entry.$1 == selectedIndex,
            onTap: () => onItemSelected(entry.$1),
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
          'KINETIC',
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
    required this.isSelected,
    required this.onTap,
  });

  final DashboardNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: item.semanticLabel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: _tileDecoration,
          child: Column(
            children: [
              Icon(item.icon, color: _contentColor, size: 20),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: AppTextStyles.navItem.copyWith(color: _contentColor),
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

  BoxDecoration get _tileDecoration {
    return BoxDecoration(
      color: isSelected ? AppColors.surfaceContainer : Colors.transparent,
      border: Border(
        left: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 4,
        ),
      ),
      boxShadow: isSelected
          ? const <BoxShadow>[
              BoxShadow(color: AppColors.primary40, blurRadius: 15),
            ]
          : null,
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
        SizedBox(height: 12),
        _VehicleBadge(),
        SizedBox(height: 16),
      ],
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  const _EmergencyButton();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.errorContainer,
        foregroundColor: AppColors.onErrorContainer,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        textStyle: AppTextStyles.emergencyButton,
      ),
      child: const Text('EMERGENCY'),
    );
  }
}

class _VehicleBadge extends StatelessWidget {
  const _VehicleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary20, width: 2),
        color: AppColors.surfaceContainer,
      ),
      child: const Icon(
        Icons.directions_car,
        color: AppColors.primary,
        size: 24,
      ),
    );
  }
}
