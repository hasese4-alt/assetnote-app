import 'package:asset_note/utils/asset_history_math.dart';
import 'package:asset_note/widgets/asset_total_diff_text.dart';
import 'package:asset_note/widgets/asset_line_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Top PageView: total + Year/Month comparison, and goal / percentile card.
class AssetsListSummary extends StatelessWidget {
  const AssetsListSummary({
    super.key,
    required this.cardController,
    required this.formatter,
    required this.totalAmount,
    required this.hideTotal,
    required this.isInitialLoading,
    required this.isConfirmed,
    required this.goalAmount,
    required this.userPercentile,
    required this.comparisonHistory,
    required this.onToggleHideTotal,
    required this.onConfirmToggle,
    required this.isYearComparison,
    required this.onYearComparisonChanged,
    required this.chartPoints,
    required this.chartLabels,
  });

  final PageController cardController;
  final NumberFormat formatter;
  final int totalAmount;
  final bool hideTotal;
  final bool isInitialLoading;
  final bool isConfirmed;
  final int goalAmount;
  final double userPercentile;
  final List<Map<String, dynamic>> comparisonHistory;
  final VoidCallback onToggleHideTotal;
  final Future<void> Function() onConfirmToggle;

  final bool isYearComparison;
  final Future<void> Function(bool useYearOverYear) onYearComparisonChanged;
  final List<double> chartPoints;
  final List<String> chartLabels;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cardColor = isLight ? Colors.white : const Color(0xFF1C1C1E);
    final shadow = isLight
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ]
        : <BoxShadow>[];

    return SizedBox(
      height: 145,
      child: PageView(
        controller: cardController,
        children: [
          // ======== 1枚目カード（総資産カード） ========
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: cardColor,
              boxShadow: shadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AssetWealthPercentileLabel(percentile: userPercentile),

                const SizedBox(height: 6),
                Center(
                  child: GestureDetector(
                    onTap: onToggleHideTotal,
                    child: isInitialLoading
                        ? const SizedBox(
                            height: 32,
                            width: 32,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(
                            hideTotal
                                ? '¥••••••'
                                : '¥${formatter.format(totalAmount)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                //const SizedBox(height: 6),
                if (!isInitialLoading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ==== Apple風 Year / Month pill ====
                      Row(children: [
                        ],
                      ),

                      //const SizedBox(width: 8),
                      // ★ ここを Expanded にすることで「幅が有限」になる
                      Expanded(
                        child: SizedBox(
                          //height: 32,
                          child: Row(
                            children: [
                              Expanded(
                                child: Center(
                                  child: AssetTotalDiffText(
                                    formatter: formatter,
                                    currentTotal: totalAmount,
                                    startTotal:
                                        AssetHistoryMath.sumHistoryValues(
                                          comparisonHistory,
                                        ),
                                    fontSize: 16,
                                  ),
                                ),
                              ),

                              // === 右：ダミー（中央寄せを安定させる） ===
                              //const SizedBox(width: 28),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ======== 2枚目カード（チャート） ========
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: cardColor,
              boxShadow: shadow,
            ),
            //child: AssetLineChart(points: chartPoints, labels: chartLabels),
          ),

          // ======== 3枚目カード（今回リリースでは非表示） ========

          /*
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: cardColor,
          boxShadow: shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (goalAmount > 0)
              _AssetGoalProgressBar(total: totalAmount, goal: goalAmount),
            const SizedBox(height: 20),

          ],
        ),
      ),
*/
        ],
      ),
    );
  }
}

class _AssetGoalProgressBar extends StatelessWidget {
  const _AssetGoalProgressBar({required this.total, required this.goal});

  final int total;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final progress = (total / goal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '目標達成率 ${(progress * 100).toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
          ),
        ),
      ],
    );
  }
}

class _AssetWealthPercentileLabel extends StatelessWidget {
  final double percentile; // 0.50 = 上位50%

  const _AssetWealthPercentileLabel({super.key, required this.percentile});

  // ★ ランク別アイコン
  String _iconForPercentile(double p) {
    final percent = p * 100;

    if (percent <= 1) return "👑"; // 上位1%
    if (percent <= 5) return "🥇"; // 上位5%
    if (percent <= 10) return "🥈"; // 上位10%
    if (percent <= 20) return "🥉"; // 上位20%
    return "📈"; // それ以外
  }

  // ★ 説明モーダル（そのまま）
  void _showExplanation(BuildContext context, double percentile) {
    final percent = (percentile * 100).toStringAsFixed(1);

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
                "日本の資産ランク",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "あなたは日本の上位 $percent% に位置しています。",
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              const Text(
                "■ 日本の資産額とランクの目安",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const Text(
                """
👑 ブラック（上位1%）
🥇 ゴールド（上位5%）
🥈 シルバー（上位10%）
🥉 ブロンズ（上位20%）
📈 赤（上位50%）
                """,
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
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

    return GestureDetector(
      onTap: () => _showExplanation(context, percentile),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 黒字ラベル
          Text(
            "資産ランク ",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),

          // ★ ドット → アイコンに変更
          Text(
            icon,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 4),

          // 上位％
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
