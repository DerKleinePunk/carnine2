import 'package:carnine_frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
import 'package:carnine_frontend/features/settings/presentation/settings_content.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Dashboard body area that shows the active section and backend probe state.
class DashboardContent extends StatelessWidget {
  const DashboardContent({
    required this.selectedItem,
    required this.grpcStatus,
    required this.receivedCanDataCount,
    required this.grpcErrorMessage,
    required this.canData,
    required this.isGrpcLoading,
    required this.onTestGrpc,
    required this.languageController,
    super.key,
  });

  final DashboardNavItem selectedItem;
  final DashboardGrpcStatus grpcStatus;
  final int receivedCanDataCount;
  final String grpcErrorMessage;
  final List<CanData> canData;
  final bool isGrpcLoading;
  final Future<void> Function() onTestGrpc;
  final AppLanguageController languageController;

  @override
  Widget build(BuildContext context) {
    if (selectedItem.destination == DashboardDestination.settings) {
      return SettingsContent(languageController: languageController);
    }

    final l10n = AppLocalizations.of(context);
    final selectedLabel = l10n.text(selectedItem.labelKey);
    final status = _localizedGrpcStatus(l10n);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.dashboardContentFor(selectedLabel),
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.grpcStatus(status),
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: isGrpcLoading ? null : onTestGrpc,
            icon: const Icon(Icons.cloud_sync, size: 18),
            label: Text(
              isGrpcLoading
                  ? l10n.text(AppTextKey.connecting)
                  : l10n.text(AppTextKey.testGrpc),
            ),
          ),
          if (canData.isNotEmpty) ...[
            const SizedBox(height: 20),
            _CanDataList(canData: canData),
          ],
        ],
      ),
    );
  }

  String _localizedGrpcStatus(AppLocalizations l10n) {
    return switch (grpcStatus) {
      DashboardGrpcStatus.notConnected =>
        l10n.text(AppTextKey.statusNotConnected),
      DashboardGrpcStatus.connecting => l10n.text(AppTextKey.statusConnecting),
      DashboardGrpcStatus.connected =>
        l10n.statusConnected(receivedCanDataCount),
      DashboardGrpcStatus.error => l10n.statusError(grpcErrorMessage),
    };
  }
}

class _CanDataList extends StatelessWidget {
  const _CanDataList({required this.canData});

  final List<CanData> canData;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 560,
      height: 160,
      child: ListView.builder(
        itemCount: canData.length,
        itemBuilder: (context, index) => _CanDataLine(data: canData[index]),
      ),
    );
  }
}

class _CanDataLine extends StatelessWidget {
  const _CanDataLine({required this.data});

  final CanData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Text(
      l10n.canDataLine(
        sensor: data.sensorId,
        value: data.value,
        timestamp: data.timestamp,
      ),
      style: AppTextStyles.bodyLarge.copyWith(
        color: AppColors.onSurface,
      ),
    );
  }
}
