import 'dart:async';

import 'package:carnine_frontend/features/dashboard/data/ui_state_store.dart';
import 'package:carnine_frontend/features/maps/presentation/maps_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/carnine_top_bar.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/dashboard_content.dart';
import 'package:carnine_frontend/features/dashboard/presentation/widgets/side_menu.dart';
import 'package:carnine_frontend/features/media/presentation/media_controller.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Main dashboard shell for the fixed car display.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.languageController,
    this.controller,
    this.mediaController,
    this.mapsController,
    this.uiStateStore,
    super.key,
  });

  final AppLanguageController languageController;
  final DashboardController? controller;
  final MediaController? mediaController;
  final MapsController? mapsController;

  /// Where the page shown last is kept; without it the dashboard always
  /// starts on the first page. Ignored when [controller] is given.
  final UiStateStore? uiStateStore;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardController _controller =
      widget.controller ??
      DashboardController(uiStateStore: widget.uiStateStore);

  // Owned here, not by MediaContent, so the queue and playback state survive
  // switching to another sidebar section and back - MediaContent would
  // otherwise be torn down and rebuilt on every visit, losing everything but
  // the currently playing path (the only thing the backend re-reports).
  late final MediaController _mediaController =
      widget.mediaController ?? MediaController();

  bool get _ownsController => widget.controller == null;
  // Same reasoning as the media controller: route, destination and the
  // position stream must survive switching to another section and back.
  late final MapsController _mapsController =
      widget.mapsController ??
      MapsController(
        // Instructions in the language set in the settings, read per route.
        language: () => widget.languageController.locale.languageCode,
      );

  bool get _ownsMediaController => widget.mediaController == null;
  bool get _ownsMapsController => widget.mapsController == null;

  DashboardGrpcStatus _lastHandledGrpcStatus = DashboardGrpcStatus.notConnected;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChange);
    unawaited(_controller.restoreLastPage());
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);
    if (_ownsController) {
      _controller.dispose();
    }
    if (_ownsMediaController) {
      _mediaController.dispose();
    }
    if (_ownsMapsController) {
      _mapsController.dispose();
    }

    super.dispose();
  }

  /// Surfaces backend connection failures as a dialog exactly once per
  /// occurrence, instead of leaking the raw exception into inline UI text.
  void _handleControllerChange() {
    final status = _controller.grpcStatus;
    if (status == DashboardGrpcStatus.error &&
        _lastHandledGrpcStatus != DashboardGrpcStatus.error) {
      _showGrpcErrorDialog();
    }

    _lastHandledGrpcStatus = status;
  }

  Future<void> _showGrpcErrorDialog() async {
    if (!mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context);

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.text(AppTextKey.grpcConnectionErrorTitle)),
        content: Text(l10n.text(AppTextKey.grpcConnectionErrorMessage)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.text(AppTextKey.close)),
          ),
        ],
      ),
    );
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
                    const CarnineTopBar(),
                    Expanded(
                      child: DashboardContent(
                        selectedItem: _controller.selectedItem,
                        grpcStatus: _controller.grpcStatus,
                        receivedCanDataCount: _controller.receivedCanDataCount,
                        canData: _controller.canData,
                        isGrpcLoading: _controller.isGrpcLoading,
                        onTestGrpc: _controller.testGrpc,
                        languageController: widget.languageController,
                        mediaController: _mediaController,
                        mapsController: _mapsController,
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
}
