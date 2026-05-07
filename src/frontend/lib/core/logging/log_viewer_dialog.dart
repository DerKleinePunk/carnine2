import 'package:carnine_frontend/l10n/app_localizations.dart';
import 'package:carnine_frontend/styles/colors.dart';
import 'package:carnine_frontend/styles/text_styles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Dialog that renders the rolling frontend log buffer.
class LogViewerDialog extends StatelessWidget {
  const LogViewerDialog({
    required this.logLines,
    super.key,
  });

  final ValueListenable<List<String>> logLines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.text(AppTextKey.frontendLogs)),
      content: SizedBox(
        width: 700,
        height: 500,
        child: ValueListenableBuilder<List<String>>(
          valueListenable: logLines,
          builder: (context, logs, child) => _LogList(logs: logs),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.text(AppTextKey.close)),
        ),
      ],
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({required this.logs});

  final List<String> logs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (logs.isEmpty) {
      return Center(
        child: Text(
          l10n.text(AppTextKey.noLogEntriesYet),
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        return Text(
          logs[index],
          style: AppTextStyles.logLine.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        );
      },
    );
  }
}
