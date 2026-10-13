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

  /// The keyboard controller, or `null` where there is no scope - for a
  /// caller that only wants to look at it and does not depend on it.
  static OnScreenKeyboardController? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<OnScreenKeyboardScope>()
        ?.notifier;
  }

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
