import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/player_core.dart';
import 'package:carnine_frontend/features/media/presentation/widgets/player/queue_sidebar.dart';
import 'package:flutter/material.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({required this.controller, super.key});

  final MediaController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.player,
      builder: (context, child) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PlayerCore(
                controller: controller.player,
                isQueueExpanded: controller.isQueueExpanded,
              ),
            ),
            QueueSidebar(controller: controller, player: controller.player),
          ],
        );
      },
    );
  }
}
