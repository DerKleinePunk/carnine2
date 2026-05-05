import 'package:carnine_frontend/features/dashboard/presentation/models/dashboard_nav_item.dart';
import 'package:carnine_frontend/lib/carnine.pb.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/material.dart';

/// Dashboard body area that shows the active section and backend probe state.
class DashboardContent extends StatelessWidget {
  const DashboardContent({
    required this.selectedItem,
    required this.grpcStatus,
    required this.canData,
    required this.isGrpcLoading,
    required this.onTestGrpc,
    super.key,
  });

  final DashboardNavItem selectedItem;
  final String grpcStatus;
  final List<CanData> canData;
  final bool isGrpcLoading;
  final Future<void> Function() onTestGrpc;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Dashboard Content for ${selectedItem.label}',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'gRPC Status: $grpcStatus',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: isGrpcLoading ? null : onTestGrpc,
            icon: const Icon(Icons.cloud_sync, size: 18),
            label: Text(isGrpcLoading ? 'Connecting' : 'Test gRPC'),
          ),
          if (canData.isNotEmpty) ...[
            const SizedBox(height: 20),
            _CanDataList(canData: canData),
          ],
        ],
      ),
    );
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
    return Text(
      'Sensor: ${data.sensorId}, Value: ${data.value}, Time: ${data.timestamp}',
      style: AppTextStyles.bodyLarge.copyWith(
        color: AppColors.onSurface,
      ),
    );
  }
}
