import 'package:asset_note/services/assets_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _fmt = NumberFormat('#,###', 'ja_JP');

class MonthlyAttributionSummary extends StatelessWidget {
  const MonthlyAttributionSummary({
    super.key,
    required this.totalChange,
    required this.assets,
    required this.labelEntries,
    required this.excludedSet,
    required this.viewYear,
    required this.viewMonth,
  });

  final int totalChange;
  final List<Map<String, dynamic>> assets;
  final Map<int, List<MonthlyLabelEntry>> labelEntries;
  final Set<int> excludedSet;
  final int viewYear;
  final int viewMonth;

  // 除外分の合計（資産全体除外 + ラベルごと除外）
  int _excludedTotal() {
    int sum = 0;
    for (final a in assets) {
      final id = a['_asset_id'] as int;
      final diff = a['_diff'] as int?;
      if (diff == null || diff == 0) continue;
      if (excludedSet.contains(id)) {
        sum += diff; // 資産全体除外
        continue;
      }
      final entries = labelEntries[id];
      if (entries == null) continue;
      for (final entry in entries) {
        if (entry.excluded) sum += (entry.amount ?? diff);
      }
    }
    return sum;
  }

  // ラベル付き（除外なし）の資産を集計。各エントリーの amount を使用
  Map<String, int> _buildLabelTotals() {
    final result = <String, int>{};
    for (final a in assets) {
      final id = a['_asset_id'] as int;
      final diff = a['_diff'] as int?;
      if (diff == null || diff == 0) continue;
      if (excludedSet.contains(id)) continue;
      final entries = labelEntries[id];
      if (entries == null || entries.isEmpty) continue;
      for (final entry in entries) {
        if (entry.excluded) continue; // per-entry 除外はスキップ
        final attributed = entry.amount ?? diff;
        result[entry.label] = (result[entry.label] ?? 0) + attributed;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final excludedTotal = _excludedTotal();
    final effectiveTotal = totalChange; // totalChange はすでに除外済み資産を含まない
    final labelTotals = _buildLabelTotals();
    final explained = labelTotals.values.fold(0, (s, v) => s + v);
    final unexplained = effectiveTotal - explained;
    final allExplained = unexplained == 0 && labelTotals.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '内訳分析',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
              ),
              const Spacer(),
              if (allExplained)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 12, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '全額説明済み',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (labelTotals.isEmpty && excludedSet.isEmpty)
            Text(
              '各資産をタップしてラベルを付けましょう',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
            )
          else ...[
            ...labelTotals.entries.map(
              (e) => _LabelRow(
                label: e.key,
                amount: e.value,
                totalChange: effectiveTotal,
              ),
            ),
            if (labelTotals.isNotEmpty)
              Divider(color: cs.outline.withValues(alpha: 0.2), height: 20),
          ],
          if (!allExplained && effectiveTotal != 0)
            _UnexplainedRow(
              amount: unexplained,
              totalChange: effectiveTotal,
            ),
          // 除外行
          if (excludedTotal != 0) ...[
            const SizedBox(height: 8),
            _ExcludedRow(amount: excludedTotal),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '合計: ${totalChange >= 0 ? "+" : ""}¥${_fmt.format(totalChange)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({
    required this.label,
    required this.amount,
    required this.totalChange,
  });

  final String label;
  final int amount;
  final int totalChange;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUp = amount >= 0;
    final pct = totalChange != 0
        ? ((amount / totalChange) * 100).abs().round()
        : 0;
    final barRatio = totalChange != 0
        ? (amount.abs() / totalChange.abs()).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${isUp ? "+" : ""}¥${_fmt.format(amount)}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isUp ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 30,
                child: Text(
                  '$pct%',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) => Container(
              height: 3,
              width: constraints.maxWidth * barRatio,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnexplainedRow extends StatelessWidget {
  const _UnexplainedRow({
    required this.amount,
    required this.totalChange,
  });

  final int amount;
  final int totalChange;

  @override
  Widget build(BuildContext context) {
    final isUp = amount >= 0;
    final pct = totalChange != 0
        ? ((amount / totalChange) * 100).abs().round()
        : 0;
    final barRatio = totalChange != 0
        ? (amount.abs() / totalChange.abs()).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.help_outline,
                      size: 13, color: Colors.orange.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '未説明（何？）',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isUp ? "+" : ""}¥${_fmt.format(amount)}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 30,
              child: Text(
                '$pct%',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.orange.shade400,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) => Container(
            height: 3,
            width: constraints.maxWidth * barRatio,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExcludedRow extends StatelessWidget {
  const _ExcludedRow({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.remove_circle_outline,
            size: 13, color: cs.onSurface.withValues(alpha: 0.35)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '除外（計算に含めない）',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
          ),
        ),
        Text(
          '${amount >= 0 ? "+" : ""}¥${_fmt.format(amount)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
        ),
      ],
    );
  }
}
