import 'package:asset_note/utils/asset_history_math.dart';
import 'package:asset_note/widgets/asset_total_diff_text.dart';
import 'package:asset_note/widgets/monthly_confirm_toggle.dart';
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
      height: 190,
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
                MonthlyConfirmToggle(
                  isConfirmed: isConfirmed,
                  onTap: onConfirmToggle,
                  size: 28,
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 10),

                if (!isInitialLoading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ==== Apple風 Year / Month pill ====
                      Row(
                        children: [
                          // ===== Year =====
                          GestureDetector(
                            onTap: () => onYearComparisonChanged(true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isYearComparison
                                    ? (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white.withOpacity(0.20)
                                          : Colors.black.withOpacity(0.10))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isYearComparison
                                      ? (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white.withOpacity(0.70)
                                            : Colors.black.withOpacity(0.60))
                                      : (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white.withOpacity(0.30)
                                            : Colors.black.withOpacity(0.20)),
                                  width: isYearComparison ? 1.4 : 1.0,
                                ),
                              ),
                              child: Text(
                                'Year',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isYearComparison
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white.withOpacity(
                                          isYearComparison ? 1.0 : 0.7,
                                        )
                                      : Colors.black.withOpacity(
                                          isYearComparison ? 1.0 : 0.7,
                                        ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 6),

                          // ===== Month =====
                          GestureDetector(
                            onTap: () => onYearComparisonChanged(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: !isYearComparison
                                    ? (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white.withOpacity(0.20)
                                          : Colors.black.withOpacity(0.10))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !isYearComparison
                                      ? (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white.withOpacity(0.70)
                                            : Colors.black.withOpacity(0.60))
                                      : (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white.withOpacity(0.30)
                                            : Colors.black.withOpacity(0.20)),
                                  width: !isYearComparison ? 1.4 : 1.0,
                                ),
                              ),
                              child: Text(
                                'Month',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: !isYearComparison
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white.withOpacity(
                                          !isYearComparison ? 1.0 : 0.7,
                                        )
                                      : Colors.black.withOpacity(
                                          !isYearComparison ? 1.0 : 0.7,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(width: 8),

                      // ==== 収益（差分） ====
                      AssetTotalDiffText(
                        formatter: formatter,
                        currentTotal: totalAmount,
                        startTotal: AssetHistoryMath.sumHistoryValues(
                          comparisonHistory,
                        ),
                        fontSize: 16,
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ======== 2枚目カード（今回リリースでは非表示） ========
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
            _AssetWealthPercentileLabel(percentile: userPercentile),
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
  const _AssetWealthPercentileLabel({required this.percentile});

  final double percentile;

  @override
  Widget build(BuildContext context) {
    if (percentile <= 0) {
      return const Text(
        '資産レベル未計測',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      );
    }
    final percent = (percentile * 100).toStringAsFixed(1);
    return Row(
      children: [
        Icon(Icons.trending_up, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Text(
          'あなたは日本の上位 $percent%',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
