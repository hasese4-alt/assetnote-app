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
    required this.sortedAssets,
    required this.groupedDisplay,
    required this.isYearComparison,
    required this.isCurrentMonth,
    required this.hideTotal,
    required this.formatter,
    required this.goalAmount,
    required this.isInitialLoading,
    required this.isConfirmed,
    required this.vmTotal,
    required this.onToggleHideTotal,
    required this.onYearComparisonChanged,
    required this.buildAssetCard,
  });

  final Future<List<Map<String, dynamic>>> startOfYearHistoryFuture;
  final Future<List<Map<String, dynamic>>> previousMonthHistoryFuture;

  final List<Map<String, dynamic>> sortedAssets;
  final Map<String, Map<String, List<Map<String, dynamic>>>> groupedDisplay;
  final bool isYearComparison;
  final bool isCurrentMonth;
  final bool hideTotal;
  final NumberFormat formatter;
  final int goalAmount;
  final bool isInitialLoading;
  final bool isConfirmed;
  final int vmTotal;

  final VoidCallback onToggleHideTotal;
  final Future<void> Function(bool useYearOverYear) onYearComparisonChanged;
  final Widget Function(
    Map<String, dynamic> asset,
    Map<int, int> startByAssetId,
    {bool isGrouped, bool isNewThisMonth}
  )
  buildAssetCard;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        startOfYearHistoryFuture,
        previousMonthHistoryFuture,
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final startOfYearHistory =
            snapshot.data![0] as List<Map<String, dynamic>>;
        final previousHistory = snapshot.data![1] as List<Map<String, dynamic>>;

        // 年初 or 前月の開始値
        final startByAssetId = AssetHistoryMath.startValuesByAssetId(
          startOfYearHistory,
        );
        final previousStartByAssetId = AssetHistoryMath.startValuesByAssetId(
          previousHistory,
        );

        // 前月に存在した資産IDセット（今月新規判定用）
        final previousMonthAssetIds = previousHistory
            .map((h) => AssetHistoryMath.coerceInt(h['asset_id']))
            .whereType<int>()
            .toSet();

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

        // 全資産（売却済みも含む）の前月（または年初）合計
        // 売却済み資産を除外すると確定時に比較基準が下がり diff が売却額分増えるバグを防ぐ
        final int comparisonStartTotal =
            AssetHistoryMath.sumHistoryValues(actualHistory);

        // カテゴリ別開始値（現存資産のみ）
        final category1StartTotals = <String, int>{};
        for (final h in actualHistory) {
          final aid = AssetHistoryMath.coerceInt(h['asset_id']);
          if (aid == null) continue;

          final asset = assetById[aid];
          if (asset == null) continue; // 削除済み資産はスキップ

          final value = h['value'] as int? ?? 0;

          final c1Id = h['category1_id'] ?? asset['category1_id'];
          if (c1Id == null) continue;

          category1StartTotals[c1Id] =
              (category1StartTotals[c1Id] ?? 0) + value;
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

          // 過去月: そのスナップショットに保存された category1_name を優先して使う
          for (final a in sortedAssets) {
            if (a['category1_id'] == c1Id) {
              final name = a['category1_name'] as String?;
              if (name != null && name.isNotEmpty) return name;
            }
          }
          // フォールバック: 年初スナップショットから解決
          for (final h in startOfYearHistory) {
            if (h['category1_id'] == c1Id) {
              return h['category1_name'] as String? ?? '未分類';
            }
          }
          return '未分類';
        }

        IconData? resolveCategory1Icon(String c1Id) {
          if (isCurrentMonth) {
            for (final a in sortedAssets) {
              if (a['category1_id'] == c1Id) {
                return categoryIconDataForKey(
                    a['categories1']?['icon'] as String?);
              }
            }
          }
          return null;
        }

        return Column(
          children: [
            AssetsListSummary(
              formatter: formatter,
              totalAmount: vmTotal,
              hideTotal: hideTotal,
              isInitialLoading: isInitialLoading,
              isConfirmed: isConfirmed,
              goalAmount: goalAmount,
              comparisonStartTotal: comparisonStartTotal,
              isYearComparison: isYearComparison,
              onToggleHideTotal: onToggleHideTotal,
              onYearComparisonChanged: onYearComparisonChanged,
            ),
            const SizedBox(height: 8),
            // カテゴリ一覧
            ...groupedDisplay.entries.map((big) {
              final bigTotal = AssetsViewModel.categoryTotal(big.value);
              return ExpansionTile(
                initiallyExpanded: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (resolveCategory1Icon(big.key) != null) ...[
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Icon(
                                resolveCategory1Icon(big.key),
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              resolveCategory1Name(big.key),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
                    final midAssets = midEntry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (int i = 0; i < midAssets.length; i++) ...[
                                buildAssetCard(
                                  midAssets[i],
                                  actualStartByAssetId,
                                  isGrouped: true,
                                  isNewThisMonth: isCurrentMonth && (() {
                                    final aid =
                                        AssetHistoryMath.coerceInt(midAssets[i]['asset_id']) ??
                                        AssetHistoryMath.coerceInt(midAssets[i]['id']);
                                    return aid != null && !previousMonthAssetIds.contains(aid);
                                  })(),
                                ),
                                if (i < midAssets.length - 1)
                                  Divider(
                                    height: 1,
                                    indent: 58,
                                    color: Theme.of(context).dividerColor,
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 4),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}
