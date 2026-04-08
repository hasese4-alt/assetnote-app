import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AssetCardWidget extends StatelessWidget {
  const AssetCardWidget({
    super.key,
    required this.asset,
    required this.isConfirmed,
    required this.isCurrentMonth,
    required this.formatter,
    required this.startOfYearValue,
    required this.onEditCurrent,
    required this.onEditHistory,
    required this.onDelete,
  });

  final Map<String, dynamic> asset;
  final bool isConfirmed;
  final bool isCurrentMonth;
  final NumberFormat formatter;
  /// Jan 1 snapshot for this asset from batch history; null if unknown.
  final int? startOfYearValue;
  final Future<void> Function() onEditCurrent;
  final Future<void> Function() onEditHistory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final start = startOfYearValue;
    final current = asset['value'] as int? ?? 0;

    int diff = 0;
    double diffRate = 0;

    if (start != null && start > 0) {
      diff = current - start;
      diffRate = (current / start - 1) * 100;
    }

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () async {
          if (isConfirmed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot edit while this month is confirmed.'),
              ),
            );
            return;
          }

          if (isCurrentMonth) {
            await onEditCurrent();
            return;
          }

          await onEditHistory();
        },
        onLongPress: () {
          if (isConfirmed) return;

          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete asset?'),
              content: Text(asset['name'] as String? ?? ''),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    onDelete();
                    Navigator.pop(context);
                  },
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.only(
            top: 0,
            left: 6,
            right: 6,
            bottom: 6,
          ),
          decoration: BoxDecoration(
            color: isConfirmed
                ? (Theme.of(context).brightness == Brightness.light
                      ? Colors.blueGrey.shade100
                      : Colors.blueGrey.shade800)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isConfirmed ? 0.02 : 0.05),
                blurRadius: isConfirmed ? 4 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    asset['name'] as String? ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatter.format(current),
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (start != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "${diff >= 0 ? '+' : ''}${formatter.format(diff)} "
                        "(${diffRate.toStringAsFixed(1)}%)",
                        style: TextStyle(
                          fontSize: 12,
                          color: diff >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                ],
              ),
              if (isConfirmed)
                Icon(
                  Icons.lock,
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.blueGrey.shade400
                      : Colors.blueGrey.shade200,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
