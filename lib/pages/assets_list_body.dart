import 'package:asset_note/pages/assets_list_summary.dart';
import 'package:asset_note/utils/asset_history_math.dart';
import 'package:asset_note/utils/category_favicon.dart';
import 'package:asset_note/viewmodels/assets_view_model.dart';
import 'package:asset_note/widgets/asset_total_diff_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class AssetsListBody extends StatelessWidget {
  const AssetsListBody({
    super.key,
    required this.startOfYearHistoryFuture,
    required this.previousMonthHistoryFuture,
    required this.graphHistoryFuture,
    required this.sortedAssets,
    required this.groupedDisplay,
    required this.isYearComparison,
    required this.isCurrentMonth,
    required this.hideTotal,
    required this.formatter,
    required this.cardController,
    required this.goalAmount,
    required this.userPercentile,
    required this.isInitialLoading,
    required this.isConfirmed,
    required this.vmTotal,
    required this.onToggleHideTotal,
    required this.onConfirmToggle,
    required this.onYearComparisonChanged,
    required this.buildAssetCard,
  });

  final Future<List<Map<String, dynamic>>> startOfYearHistoryFuture;
  final Future<List<Map<String, dynamic>>> previousMonthHistoryFuture;
  final Future<List<Map<String, dynamic>>> graphHistoryFuture;

  final List<Map<String, dynamic>> sortedAssets;
  final Map<String, Map<String, List<Map<String, dynamic>>>> groupedDisplay;
  final bool isYearComparison;
  final bool isCurrentMonth;
  final bool hideTotal;
  final NumberFormat formatter;
  final PageController cardController;
  final int goalAmount;
  final double userPercentile;
  final bool isInitialLoading;
  final bool isConfirmed;
  final int vmTotal;

  final VoidCallback onToggleHideTotal;
  final Future<void> Function() onConfirmToggle;
  final Future<void> Function(bool useYearOverYear) onYearComparisonChanged;
  final Widget Function(
    Map<String, dynamic> asset,
    Map<int, int> startByAssetId,
  )
  buildAssetCard;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        startOfYearHistoryFuture,
        previousMonthHistoryFuture,
        graphHistoryFuture, // ← monthlyList の正体
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final startOfYearHistory =
            snapshot.data![0] as List<Map<String, dynamic>>;
        final previousHistory = snapshot.data![1] as List<Map<String, dynamic>>;
        final monthlyList =
            snapshot.data![2] as List<Map<String, dynamic>>; // ← 本物

        // グラフ用
        final points = monthlyList
            .map((e) => (e['total'] as num).toDouble())
            .toList();

        final labels = monthlyList.map((e) => "${e['month']}月").toList();

        // 年初 or 前月の開始値
        final startByAssetId = AssetHistoryMath.startValuesByAssetId(
          startOfYearHistory,
        );
        final previousStartByAssetId = AssetHistoryMath.startValuesByAssetId(
          previousHistory,
        );

        final actualHistory = isYearComparison
            ? startOfYearHistory
            : previousHistory;
        final actualStartByAssetId = isYearComparison
            ? startByAssetId
            : previousStartByAssetId;

        // asset_id → asset データ
        final assetById = <int, Map<String, dynamic>>{};
        for (final asset in sortedAssets) {
          final key =
              AssetHistoryMath.coerceInt(asset['asset_id']) ??
              AssetHistoryMath.coerceInt(asset['id']);
          if (key != null) assetById[key] = asset;
        }

        // カテゴリ1開始値
        final category1StartTotals = <String, int>{};
        for (final h in actualHistory) {
          final aid = AssetHistoryMath.coerceInt(h['asset_id']);
          if (aid == null) continue;

          final asset = assetById[aid];
          if (asset == null) continue;

          final value = h['value'] as int? ?? 0;
          final c1Id = h['category1_id'] ?? asset['category1_id'];
          if (c1Id == null) continue;

          category1StartTotals[c1Id] =
              (category1StartTotals[c1Id] ?? 0) + value;
        }

        // カテゴリ1終了値
        final category1EndTotals = <String, int>{};
        for (final a in sortedAssets) {
          final c1Id = a['category1_id'];
          if (c1Id == null) continue;

          final value = a['value'] as int? ?? 0;
          category1EndTotals[c1Id] = (category1EndTotals[c1Id] ?? 0) + value;
        }

        String resolveCategory1Name(String c1Id) {
          if (isCurrentMonth) {
            for (final a in sortedAssets) {
              if (a['category1_id'] == c1Id) {
                return a['categories1']?['name'] ?? '未分類';
              }
            }
            return '未分類';
          }

          for (final h in startOfYearHistory) {
            if (h['category1_id'] == c1Id) {
              return h['category1_name'] as String? ?? '未分類';
            }
          }
          return '未分類';
        }

        String resolveCategory2Name(String c2Id) {
          if (isCurrentMonth) {
            for (final a in sortedAssets) {
              if (a['category2_id'] == c2Id) {
                return a['categories2']?['name'] ?? '未分類';
              }
            }
            return '未分類';
          }

          for (final h in startOfYearHistory) {
            if (h['category2_id'] == c2Id) {
              return h['category2_name'] as String? ?? '未分類';
            }
          }
          return '未分類';
        }

        return Column(
          children: [
            // Yearly / Monthly 切り替え
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => onYearComparisonChanged(true),
                    child: Text(
                      'Yearly',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isYearComparison
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('|'),
                  ),
                  GestureDetector(
                    onTap: () => onYearComparisonChanged(false),
                    child: Text(
                      'Monthly',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: !isYearComparison
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 総資産カード
            AssetsListSummary(
              cardController: cardController,
              formatter: formatter,
              totalAmount: vmTotal,
              hideTotal: hideTotal,
              isInitialLoading: isInitialLoading,
              isConfirmed: isConfirmed,
              goalAmount: goalAmount,
              userPercentile: userPercentile,
              comparisonHistory: actualHistory,
              onToggleHideTotal: onToggleHideTotal,
              onConfirmToggle: onConfirmToggle,
              isYearComparison: isYearComparison,
              onYearComparisonChanged: onYearComparisonChanged,
              chartPoints: points,
              chartLabels: labels,
            ),

            // カテゴリ一覧
            ...groupedDisplay.entries.map((big) {
              final bigTotal = AssetsViewModel.categoryTotal(big.value);
              return ExpansionTile(
                initiallyExpanded: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: categoryTitleWithOptionalFavicon(
                        label: resolveCategory1Name(big.key),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          hideTotal
                              ? '¥••••••'
                              : '¥${formatter.format(bigTotal)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        AssetTotalDiffText(
                          formatter: formatter,
                          currentTotal: bigTotal,
                          startTotal: category1StartTotals[big.key] ?? 0,
                          fontSize: 12,
                        ),
                      ],
                    ),
                  ],
                ),
                children: [
                  ...big.value.entries.map((midEntry) {
                    final midKey = midEntry.key;
                    final midAssets = midEntry.value;

                    final midTotal = AssetsViewModel.secondCategoryTotal(
                      midAssets,
                    );
                    final midLabel = resolveCategory2Name(midKey);

                    return ExpansionTile(
                      initiallyExpanded: true,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // ★ インデントの代わりに軽いマーカーを付ける
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Text(
                                midLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                hideTotal ? '¥••••••' : '¥${formatter.format(midTotal)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              AssetTotalDiffText(
                                formatter: formatter,
                                currentTotal: midTotal,
                                startTotal:
                                    AssetHistoryMath.startTotalForAssets(
                                      midAssets,
                                      actualStartByAssetId,
                                    ),
                                fontSize: 11,
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          itemCount: midAssets.length,
                          itemBuilder: (context, index) {
                            final a = midAssets[index];
                            return buildAssetCard(a, actualStartByAssetId);
                          },
                        ),
                      ],
                    );
                  }),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}
