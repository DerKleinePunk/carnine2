import 'package:flutter/widgets.dart';

import 'on_screen_keyboard_controller.dart';

/// Makes the app-wide [OnScreenKeyboardController] reachable from any
/// [OnScreenTextField], no matter which feature screen it lives on.
class OnScreenKeyboardScope
    extends InheritedNotifier<OnScreenKeyboardController> {
  const OnScreenKeyboardScope({
    required OnScreenKeyboardController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static OnScreenKeyboardController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<OnScreenKeyboardScope>();
    if (scope == null) {
      throw StateError(
          'OnScreenKeyboardScope is not available in this context.');
    }

    return scope.notifier!;
  }
}
