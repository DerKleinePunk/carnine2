import 'package:carnine_frontend/core/logging/app_logging.dart';
import 'package:carnine_frontend/core/logging/log_viewer_dialog.dart';
import 'package:carnine_frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/carnine_top_bar.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/dashboard_content.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/side_menu.dart';
import 'package:flutter/material.dart';

/// Main dashboard shell for the fixed car display.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    this.controller,
    super.key,
  });

  final DashboardController? controller;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardController _controller =
      widget.controller ?? DashboardController();

  bool get _ownsController => widget.controller == null;

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Scaffold(
          body: Row(
            children: [
              SideMenu(
                items: DashboardController.navItems,
                selectedIndex: _controller.selectedIndex,
                onItemSelected: _controller.selectItem,
              ),
              Expanded(
                child: Column(
                  children: [
                    CarnineTopBar(onShowLogs: _showLogViewer),
                    Expanded(
                      child: DashboardContent(
                        selectedItem: _controller.selectedItem,
                        grpcStatus: _controller.grpcStatus,
                        canData: _controller.canData,
                        isGrpcLoading: _controller.isGrpcLoading,
                        onTestGrpc: _controller.testGrpc,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogViewer() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return LogViewerDialog(logLines: AppLogging.lines);
      },
    );
  }
}
