import 'package:carnine_frontend/app/app_theme.dart';
import 'package:carnine_frontend/features/dashboard/presentation/dashboard_screen.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Root widget for the Carnine frontend.
///
/// The widget owns global Material configuration only. Feature navigation and
/// screen state live below this layer so the application bootstrap stays small.
class CarnineApp extends StatefulWidget {
  const CarnineApp({super.key});

  @override
  State<CarnineApp> createState() => _CarnineAppState();
}

class _CarnineAppState extends State<CarnineApp> {
  late final AppLanguageController _languageController =
      AppLanguageController();

  @override
  void dispose() {
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _languageController,
      builder: (context, child) {
        return MaterialApp(
          onGenerateTitle: (context) {
            return AppLocalizations.of(context).text(AppTextKey.appTitle);
          },
          debugShowCheckedModeBanner: false,
          theme: CarnineTheme.dark,
          locale: _languageController.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DashboardScreen(languageController: _languageController),
        );
      },
    );
  }
}
