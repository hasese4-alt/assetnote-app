import 'dart:math';

import 'package:asset_note/services/assets_repository.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kCategoryColors = [
  Color(0xFF4E7FFF),
  Color(0xFF34C759),
  Color(0xFFFF9F0A),
  Color(0xFFBF5AF2),
  Color(0xFF64D2FF),
  Color(0xFFFF6B6B),
  Color(0xFF5AC8FA),
  Color(0xFFFFD60A),
];

final _yen = NumberFormat('#,###', 'ja_JP');

class SellProfitBarChart extends StatefulWidget {
  const SellProfitBarChart({
    super.key,
    required this.months,
    required this.refreshKey,
    this.categoryColors,
  });

  /// 昇順（古い順）で渡す
  final List<(int, int)> months;
  final int refreshKey;
  /// カテゴリID -> 色のマップ。指定時は _kCategoryColors より優先する。
  final Map<String, Color>? categoryColors;

  @override
  State<SellProfitBarChart> createState() => _SellProfitBarChartState();
}

class _SellProfitBarChartState extends State<SellProfitBarChart> {
  late final AssetsRepository _repo;
  List<Map<String, dynamic>> _raw = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = AssetsRepository(Supabase.instance.client);
    _fetch();
  }

  @override
  void didUpdateWidget(SellProfitBarChart old) {
    super.didUpdateWidget(old);
    if (_monthsChanged(old.months, widget.months) ||
        old.refreshKey != widget.refreshKey) {
      _fetch();
    }
  }

  bool _monthsChanged(List<(int, int)> a, List<(int, int)> b) {
    if (a.length != b.length) return true;
    if (a.isEmpty) return false;
    return a.first != b.first || a.last != b.last;
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await _repo.fetchMonthlySellProfits(months: widget.months);
      if (!mounted) return;
      setState(() {
        _raw = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final months = widget.months;

    // aggregate: (year, month) -> categoryId -> profit
    final monthProfits = <(int, int), Map<String, int>>{};
    final catNames = <String, String>{};

    for (final m in months) {
      monthProfits[m] = {};
    }
    for (final row in _raw) {
      final y = row['year'] as int;
      final mo = row['month'] as int;
      final catId = row['category1_id'] as String;
      final catName = row['category1_name'] as String;
      final profit = row['profit'] as int;
      final key = (y, mo);
      if (monthProfits.containsKey(key)) {
        monthProfits[key]![catId] = (monthProfits[key]![catId] ?? 0) + profit;
        catNames[catId] = catName;
      }
    }

    final hasData = monthProfits.values.any((m) => m.isNotEmpty);

    if (!hasData) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '売却データがありません',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
          ),
        ),
      );
    }

    // assign category colors (stable order)
    final allCatIds = catNames.keys.toList();
    final catColors = <String, Color>{};
    for (int i = 0; i < allCatIds.length; i++) {
      catColors[allCatIds[i]] = widget.categoryColors?[allCatIds[i]]
          ?? _kCategoryColors[i % _kCategoryColors.length];
    }

    // build bar groups
    double maxY = 0;
    double minY = 0;
    final barGroups = <BarChartGroupData>[];
    final netByIndex = <int, int>{};

    for (int i = 0; i < months.length; i++) {
      final m = months[i];
      final profs = monthProfits[m]!;

      double posTotal = 0;
      double negTotal = 0;
      final posItems = <BarChartRodStackItem>[];
      final negItems = <BarChartRodStackItem>[];

      for (final catId in allCatIds) {
        final p = (profs[catId] ?? 0).toDouble();
        final color = catColors[catId] ?? Colors.grey;
        if (p > 0) {
          posItems.add(BarChartRodStackItem(posTotal, posTotal + p, color));
          posTotal += p;
        } else if (p < 0) {
          negItems.add(BarChartRodStackItem(negTotal + p, negTotal, color));
          negTotal += p;
        }
      }

      maxY = max(maxY, posTotal);
      minY = min(minY, negTotal);
      netByIndex[i] = posTotal.round() + negTotal.round();

      final allItems = [...negItems, ...posItems];

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              fromY: negTotal,
              toY: posTotal,
              rodStackItems: allItems.isEmpty
                  ? [BarChartRodStackItem(0, 0, Colors.transparent)]
                  : allItems,
              width: _barWidth(months.length),
              color: Colors.transparent,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(posTotal > 0 ? 4 : 0),
                bottom: Radius.circular(negTotal < 0 ? 4 : 0),
              ),
            ),
          ],
        ),
      );
    }

    // Y axis padding
    final yRange = maxY - minY;
    final padding = yRange == 0 ? 50000.0 : yRange * 0.18;
    maxY = maxY + padding;
    if (minY < 0) minY = minY - padding;
    if (maxY <= 0) maxY = 50000;

    final interval = _niceInterval(maxY - minY);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 148,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              minY: minY,
              groupsSpace:
                  months.length <= 6 ? 16 : months.length <= 12 ? 10 : 6,
              barGroups: barGroups,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) =>
                      cs.inverseSurface.withValues(alpha: 0.9),
                  getTooltipItem: (group, _, rod, rodIndex) {
                    final net = netByIndex[group.x] ?? 0;
                    final m = months[group.x];
                    final sign = net >= 0 ? '+' : '';
                    return BarTooltipItem(
                      '${m.$1}年${m.$2}月\n$sign¥${_yen.format(net)}',
                      TextStyle(
                        color: cs.onInverseSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: cs.onSurface.withValues(alpha: 0.08),
                  strokeWidth: 0.5,
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(
                      color: cs.onSurface.withValues(alpha: 0.15), width: 1),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: interval,
                    getTitlesWidget: (v, meta) {
                      if (v == meta.max || v == meta.min) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          _yLabel(v),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(fontSize: 9),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    getTitlesWidget: (v, meta) {
                      final i = v.round();
                      if ((v - i).abs() > 0.01 ||
                          i < 0 ||
                          i >= months.length) {
                        return const SizedBox.shrink();
                      }
                      if (months.length > 12 && i % 3 != 0) {
                        return const SizedBox.shrink();
                      }
                      if (months.length > 6 &&
                          months.length <= 12 &&
                          i % 2 != 0) {
                        return const SizedBox.shrink();
                      }
                      final m = months[i];
                      final now = DateTime.now();
                      final label = m.$1 == now.year
                          ? '${m.$2}月'
                          : '${m.$1 % 100}年${m.$2}月';
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          label,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(fontSize: 9),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        // legend
        if (allCatIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: allCatIds
                .map((catId) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: catColors[catId],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          catNames[catId] ?? '不明',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                fontSize: 10,
                                color: cs.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  double _barWidth(int count) {
    if (count <= 6) return 28;
    if (count <= 12) return 18;
    return 12;
  }

  String _yLabel(double v) {
    final abs = v.abs();
    final sign = v < 0 ? '-' : '';
    if (abs >= 1000000) {
      final m = (v / 1000000).toStringAsFixed(1).replaceAll('.0', '');
      return '${m}M';
    }
    final man = (v / 10000).round();
    return '$sign${man.abs()}万';
  }

  double _niceInterval(double range) {
    if (range <= 0) return 100000;
    final rough = range / 4;
    final magnitude = pow(10, (log(rough) / ln10).floor()).toDouble();
    final normalized = rough / magnitude;
    final step = normalized < 1.5
        ? 1.0
        : normalized < 3.5
            ? 2.0
            : normalized < 7.5
                ? 5.0
                : 10.0;
    return step * magnitude;
  }
}
