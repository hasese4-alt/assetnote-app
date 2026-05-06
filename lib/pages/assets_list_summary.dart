import 'package:asset_note/viewmodels/assets_view_model.dart';
import 'package:asset_note/widgets/asset_total_diff_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AssetsListSummary extends StatelessWidget {
  const AssetsListSummary({
    super.key,
    required this.formatter,
    required this.totalAmount,
    required this.hideTotal,
    required this.isInitialLoading,
    required this.isConfirmed,
    required this.goalAmount,
    required this.userPercentile,
    required this.ageGroup,
    required this.comparisonStartTotal,
    required this.isYearComparison,
    required this.onToggleHideTotal,
    required this.onConfirmToggle,
    required this.onYearComparisonChanged,
  });

  final NumberFormat formatter;
  final int totalAmount;
  final bool hideTotal;
  final bool isInitialLoading;
  final bool isConfirmed;
  final int goalAmount;
  final double userPercentile;
  final String ageGroup;
  final int comparisonStartTotal;
  final bool isYearComparison;
  final VoidCallback onToggleHideTotal;
  final Future<void> Function() onConfirmToggle;
  final Future<void> Function(bool useYearOverYear) onYearComparisonChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 総資産ラベル + 比較切替トグル
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: onToggleHideTotal,
                  child: Text(
                    '総資産',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
                const Spacer(),
                _ComparisonToggle(
                  isYearComparison: isYearComparison,
                  onChanged: onYearComparisonChanged,
                ),
              ],
            ),
            const SizedBox(height: 2),

            // ランク表示
            _AssetWealthPercentileLabel(
              percentile: userPercentile,
              ageGroup: ageGroup,
            ),
            const SizedBox(height: 4),

            // 総資産額
            GestureDetector(
              onTap: onToggleHideTotal,
              child: isInitialLoading
                  ? const SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(
                      hideTotal
                          ? '¥••••••'
                          : '¥${formatter.format(totalAmount)}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),

            // 差分テキスト
            if (!isInitialLoading) ...[
              const SizedBox(height: 2),
              AssetTotalDiffText(
                formatter: formatter,
                currentTotal: totalAmount,
                startTotal: comparisonStartTotal,
                fontSize: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComparisonToggle extends StatelessWidget {
  const _ComparisonToggle({
    required this.isYearComparison,
    required this.onChanged,
  });

  final bool isYearComparison;
  final Future<void> Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            label: '年初比',
            isActive: isYearComparison,
            onTap: () => onChanged(true),
          ),
          _ToggleChip(
            label: '前月比',
            isActive: !isYearComparison,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}

class _AssetWealthPercentileLabel extends StatelessWidget {
  final double percentile;
  final String ageGroup;

  const _AssetWealthPercentileLabel({
    required this.percentile,
    required this.ageGroup,
  });

  String _iconForPercentile(double p) {
    final percent = p * 100;
    if (percent <= 3) return "👑";
    if (percent <= 5) return "🥇";
    if (percent <= 10) return "🥈";
    if (percent <= 20) return "🥉";
    return "📈";
  }

  void _showExplanation(BuildContext context, double percentile) {
    final percent = (percentile * 100).toStringAsFixed(1);
    final ageLabel = AssetsViewModel.ageGroupJapaneseLabel(ageGroup);
    final thresholds =
        AssetsViewModel.defaultWealthThresholdsByAge[ageGroup] ?? [];

    String formatManYen(int yen) {
      if (yen >= 100_000_000) {
        final oku = yen / 100_000_000;
        return oku == oku.truncateToDouble()
            ? '${oku.toInt()}億円'
            : '${oku.toStringAsFixed(1)}億円';
      }
      return '${yen ~/ 10_000}万円';
    }

    Widget buildTierRow(String icon, String label, String range) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            Text(
              range,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "同世代の資産ランク",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "あなたは$ageLabel の同世代の中で 上位 $percent% に位置しています。",
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              Text(
                "■ $ageLabel の資産ランクの目安",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              if (thresholds.length >= 5) ...[
                buildTierRow(
                  "👑",
                  "ブラック（上位3%）",
                  "${formatManYen(thresholds[4])}以上",
                ),
                buildTierRow(
                  "🥇",
                  "ゴールド（上位5%）",
                  "${formatManYen(thresholds[3])}〜${formatManYen(thresholds[4])}",
                ),
                buildTierRow(
                  "🥈",
                  "シルバー（上位10%）",
                  "${formatManYen(thresholds[2])}〜${formatManYen(thresholds[3])}",
                ),
                buildTierRow(
                  "🥉",
                  "ブロンズ（上位20%）",
                  "${formatManYen(thresholds[1])}〜${formatManYen(thresholds[2])}",
                ),
                buildTierRow(
                  "📈",
                  "スタンダード（上位50%）",
                  "${formatManYen(thresholds[0])}〜${formatManYen(thresholds[1])}",
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                "※ 日本の家計資産分布の統計をもとにした概算値です。",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (percentile <= 0) {
      return const Text(
        '資産レベル未計測',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      );
    }

    final percent = (percentile * 100).toStringAsFixed(1);
    final icon = _iconForPercentile(percentile);
    final ageLabel = AssetsViewModel.ageGroupJapaneseLabel(ageGroup);

    return GestureDetector(
      onTap: () => _showExplanation(context, percentile),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$ageLabel ランク ",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          Text(
            icon,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            "上位 $percent%",
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}
