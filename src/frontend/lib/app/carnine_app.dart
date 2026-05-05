import 'package:carnine_frontend/app/app_theme.dart';
import 'package:carnine_frontend/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';

/// Root widget for the Carnine frontend.
///
/// The widget owns global Material configuration only. Feature navigation and
/// screen state live below this layer so the application bootstrap stays small.
class CarnineApp extends StatelessWidget {
  const CarnineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carnine',
      debugShowCheckedModeBanner: false,
      theme: CarnineTheme.dark,
      home: const DashboardScreen(),
    );
  }
}
