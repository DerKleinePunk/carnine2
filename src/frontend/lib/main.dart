import 'package:flutter/material.dart';
import 'styles/colors.dart';
import 'styles/text_styles.dart';

void main() {
  runApp(const CarnineApp());
}

class CarnineApp extends StatelessWidget {
  const CarnineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carnine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          onSurface: AppColors.onSurface,
        ),
        textTheme: const TextTheme(
          headlineLarge: AppTextStyles.headlineLarge,
          bodyLarge: AppTextStyles.bodyLarge,
          labelLarge: AppTextStyles.labelLarge,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<String> _navItems = ['Home', 'Maps', 'Media', 'Climate', 'Settings'];
  final List<IconData> _navIcons = [
    Icons.home,
    Icons.map,
    Icons.play_circle,
    Icons.thermostat,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // SideNavBar
          Container(
            width: 96, // w-24 in Tailwind ~96px
            color: AppColors.surface,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'KINETIC',
                      style: AppTextStyles.kineticBrand.copyWith(color: AppColors.primary),
                    ),
                    Text(
                      'V8-ACTIVE',
                      style: AppTextStyles.kineticSubtitle.copyWith(color: AppColors.primary40),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(_navItems.length, (index) {
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIndex = index),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _selectedIndex == index ? AppColors.surfaceContainer : Colors.transparent,
                            border: Border(
                              left: BorderSide(
                                color: _selectedIndex == index ? AppColors.primary : Colors.transparent,
                                width: 4,
                              ),
                            ),
                            boxShadow: _selectedIndex == index
                                ? [BoxShadow(color: AppColors.primary40, blurRadius: 15)]
                                : null,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _navIcons[index],
                                color: _selectedIndex == index ? AppColors.primary : AppColors.onSurfaceVariant,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _navItems[index],
                                style: AppTextStyles.navItem.copyWith(
                                  color: _selectedIndex == index ? AppColors.primary : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.errorContainer,
                        foregroundColor: AppColors.onErrorContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        textStyle: AppTextStyles.emergencyButton,
                      ),
                      child: const Text('EMERGENCY'),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary20, width: 2),
                        color: AppColors.surfaceContainer, // Hintergrund für Icon
                      ),
                      child: Icon(
                        Icons.directions_car, // Auto-Icon als Platzhalter
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // TopAppBar
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'CarNiNe',
                        style: AppTextStyles.appBarTitle.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Container(height: 12, width: 1, color: AppColors.outlineVariant20),
                      const SizedBox(width: 12),
                      Icon(Icons.signal_cellular_4_bar, color: AppColors.primary, size: 12),
                      const SizedBox(width: 8),
                      Icon(Icons.battery_full, color: AppColors.primary, size: 12),
                      const SizedBox(width: 8),
                      Icon(Icons.light_mode, color: AppColors.primary, size: 12),
                    ],
                  ),
                ),
                // Body
                Expanded(
                  child: Center(
                    child: Text(
                      'Dashboard Content for ${_navItems[_selectedIndex]}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
