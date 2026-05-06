import 'package:asset_note/utils/category_favicon.dart';
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

    final cs = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () async {
          if (isConfirmed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('この月は確定済みのため編集できません。'),
              ),
            );
            return;
          }

          if (isCurrentMonth) {
            await onEditCurrent();
          } else {
            await onEditHistory();
          }
        },
        onLongPress: () {
          if (isConfirmed) return;

          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('資産を削除しますか？'),
              content: Text(asset['name'] as String? ?? ''),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () {
                    onDelete();
                    Navigator.pop(context);
                  },
                  child: const Text('削除'),
                ),
              ],
            ),
          );
        },

        // ======== 横長リスト型カード ========
        child: Container(
          margin: const EdgeInsets.symmetric(
            vertical: 2,
            horizontal: 16,
          ), // ← 間隔広げた
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ), // ← 縦を詰めた
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isConfirmed
                  ? cs.primary.withValues(alpha: 0.4)
                  : cs.outlineVariant.withValues(alpha: 0.4),
              width: 1.1,
            ),
          ),

          child: Row(
            children: [
              // ==== 左：アイコン ====
              _AssetIcon(name: asset['name'] as String? ?? '', cs: cs),

              const SizedBox(width: 12),

              // ==== 中央：名前 + 金額 ====
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset['name'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatter.format(current),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // ==== 右：差分 ====
              if (start != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${diff >= 0 ? '+' : ''}${formatter.format(diff)}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: diff >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      "(${diffRate.toStringAsFixed(1)}%)",
                      style: TextStyle(
                        fontSize: 11,
                        color: diff >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),

              const SizedBox(width: 8),

              if (isConfirmed) Icon(Icons.lock, size: 15, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetIcon extends StatelessWidget {
  const _AssetIcon({required this.name, required this.cs});

  final String name;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final url = faviconUrlForCategoryLabel(name);
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: url != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                url,
                width: 20,
                height: 20,
                errorBuilder: (context2, e, stack) => _fallbackText(),
              ),
            )
          : _fallbackText(),
    );
  }

  Widget _fallbackText() => Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: cs.primary,
        ),
      );
}
