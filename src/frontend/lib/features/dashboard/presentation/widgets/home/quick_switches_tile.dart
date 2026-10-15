import 'dart:async';

import 'package:carnine_frontend/features/controls/domain/control.dart';
import 'package:carnine_frontend/features/controls/presentation/controls_controller.dart';
import 'package:carnine_frontend/features/controls/presentation/widgets/control_switch_card.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/home/home_tile.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The quick switches of the start page (#94): the first switches of the
/// Technik page, switched with one tap, without the sliders.
class QuickSwitchesTile extends StatelessWidget {
  const QuickSwitchesTile({required this.controller, super.key});

  /// How many switches the tile shows at most: one row.
  static const int maxSwitches = 4;

  /// The tile is only there once the backend lists a switch.
  static List<ControlDefinition> switchesOf(ControlsController controller) {
    if (controller.status != ControlsStatus.ready) {
      return const [];
    }
    return [
      for (final control in controller.controls)
        if (control.kind == ControlKind.toggle) control,
    ].take(maxSwitches).toList();
  }

  final ControlsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final switches = switchesOf(controller);

    return HomeTile(
      title: l10n.text(AppTextKey.homeSwitchesTitle),
      child: Row(
        children: [
          for (var i = 0; i < maxSwitches; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: i < switches.length
                  ? _card(switches[i])
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(ControlDefinition control) {
    final id = control.id;
    return ControlSwitchCard(
      key: ValueKey<String>('quick-$id'),
      compact: true,
      name: control.name,
      isOn: controller.isOn(id),
      isAvailable: controller.isAvailable(id),
      onTap: () => unawaited(controller.toggle(id)),
    );
  }
}
