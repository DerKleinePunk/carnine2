import 'package:flutter/material.dart';

import 'keyboard_panel.dart';
import 'on_screen_keyboard_controller.dart';

/// Every layer has exactly 3 character rows plus the shared bottom row.
const double _panelHeight = 4 * keyRowHeight + 28;

/// App-wide, always-mounted keyboard surface. Slides in from the bottom
/// when [controller] has an active field, and back out on close - staying
/// mounted (rather than being built conditionally) is what lets both
/// directions animate within the project's 200ms motion budget.
class OnScreenKeyboardOverlay extends StatelessWidget {
  const OnScreenKeyboardOverlay({required this.controller, super.key});

  final OnScreenKeyboardController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          left: 0,
          right: 0,
          bottom: controller.isOpen ? 0 : -_panelHeight,
          child: const KeyboardPanel(),
        );
      },
    );
  }
}
