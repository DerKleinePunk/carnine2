import 'package:carnine_frontend/features/media/presentation/media_content.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounts [MediaContent] with an injected [controller] inside a minimal
/// localized `MaterialApp`, without going through `CarnineApp` (which would
/// open a real gRPC socket once the media feature is wired to one).
Widget mediaHarness(MediaController controller) {
  return MaterialApp(
    locale: const Locale('de'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: MediaContent(controller: controller)),
  );
}

/// Sets the fixed 1024x600 target display size, matching every existing
/// widget test in this suite.
void setUpMediaView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1024, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
