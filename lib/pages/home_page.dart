import 'package:asset_note/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/viewmodels/assets_view_model.dart';
import 'package:asset_note/utils/asset_history_math.dart';
import 'package:asset_note/utils/yen_format.dart';
import 'package:asset_note/widgets/asset_line_chart.dart';
import 'package:asset_note/widgets/sell_profit_bar_chart.dart';

typedef _CategoryData = ({
  String id,
  String name,
  int currentTotal,
  int startTotal,
  int prevTotal,
});

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.refreshNotifier, required this.hideTotalNotifier});
  final ValueNotifier<int> refreshNotifier;
  final ValueNotifier<bool> hideTotalNotifier;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final AssetsRepository _repo;
  late final AssetsViewModel _viewModel;

  bool _isLoading = true;
  bool _isYearComparison = true;
  int _touchedIndex = -1;
  int _fiscalStartMonth = 1;

  int _total = 0;
  int _prevTotal = 0;
  int _startTotal = 0;
  List<_CategoryData> _categories = [];
  List<double> _graphPoints = [];
  List<String> _graphLabels = [];
  int _yearSellProfit = 0;


  static const _chartColors = AppColors.chartPalette;

  @override
  void initState() {
    super.initState();
    _repo = AssetsRepository(Supabase.instance.client);
    _viewModel = AssetsViewModel(_repo);
    widget.refreshNotifier.addListener(_reload);
    widget.hideTotalNotifier.addListener(_onHideTotalChanged);
    _reload();
  }

  void _onHideTotalChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleHideTotal() async {
    widget.hideTotalNotifier.value = !widget.hideTotalNotifier.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideTotal', widget.hideTotalNotifier.value);
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_reload);
    widget.hideTotalNotifier.removeListener(_onHideTotalChanged);
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final fiscalStartMonth = prefs.getInt('fiscalYearStartMonth') ?? 1;

    final now = DateTime.now();

    final fyStartYear = now.month >= fiscalStartMonth ? now.year : now.year - 1;
    final fyMonths = <(int, int)>[];
    var fyC = DateTime(fyStartYear, fiscalStartMonth);
    while (!fyC.isAfter(now)) {
      fyMonths.add((fyC.year, fyC.month));
      fyC = DateTime(fyC.year, fyC.month + 1);
    }

    final resultsFuture = Future.wait<List<Map<String, dynamic>>>([
      _repo.fetchCurrentAssets(),
      _repo.fetchPreviousMonthHistory(year: now.year, month: now.month),
      _repo.fetchStartOfYearHistory(year: now.year),
      _viewModel.fetchGraphHistory(),
    ]);
    final yearTotalsFuture = _repo.fetchFiscalYearTotals(months: fyMonths);

    final results = await resultsFuture;
    final yearTotals = await yearTotalsFuture;

    final currentAssets = results[0];
    final prevHistory = results[1];
    final startHistory = results[2];
    var graphHistory = results[3];

    final total = AssetsViewModel.total(currentAssets);

    graphHistory = List<Map<String, dynamic>>.from(
      graphHistory.where((h) => !(h['year'] == now.year && h['month'] == now.month)),
    )..add({'year': now.year, 'month': now.month, 'total': total});

    final prevTotal = AssetHistoryMath.sumHistoryValues(prevHistory);
    final startByAssetId = AssetHistoryMath.startValuesByAssetId(startHistory);
    final startTotal = AssetHistoryMath.startTotalForAssets(currentAssets, startByAssetId);

    final assetIdToC1Id = <int, String>{};
    for (final a in currentAssets) {
      final aid = AssetHistoryMath.coerceInt(a['id']);
      if (aid == null) continue;
      final c1Id = a['category1_id'] as String?;
      if (c1Id != null) assetIdToC1Id[aid] = c1Id;
    }

    final prevByC1Id = <String, int>{};
    for (final h in prevHistory) {
      final aid = AssetHistoryMath.coerceInt(h['asset_id']);
      if (aid == null || !assetIdToC1Id.containsKey(aid)) continue;
      final c1Id = (h['category1_id'] as String?) ?? assetIdToC1Id[aid];
      if (c1Id == null) continue;
      final value = AssetHistoryMath.coerceInt(h['value']) ?? 0;
      prevByC1Id[c1Id] = (prevByC1Id[c1Id] ?? 0) + value;
    }

    final grouped = AssetsViewModel.groupForDisplay(currentAssets);
    final categories = <_CategoryData>[];
    for (final entry in grouped.entries) {
      final c1Total = AssetsViewModel.categoryTotal(entry.value);

      String name = entry.key;
      int c1StartTotal = 0;
      for (final list in entry.value.values) {
        for (final asset in list) {
          final aid = AssetHistoryMath.coerceInt(asset['id']);
          if (aid != null) c1StartTotal += startByAssetId[aid] ?? 0;
        }
        if (list.isNotEmpty && name == entry.key) {
          final cats1 = list.first['categories1'];
          if (cats1 != null && cats1['name'] != null) {
            name = cats1['name'] as String;
          }
        }
      }

      final c1PrevTotal = prevByC1Id[entry.key] ?? 0;

      if (c1Total > 0) {
        categories.add((
          id: entry.key,
          name: name,
          currentTotal: c1Total,
          startTotal: c1StartTotal,
          prevTotal: c1PrevTotal,
        ));
      }
    }

    final points = graphHistory
        .map((h) => ((h['total'] as int?) ?? 0).toDouble())
        .toList();
    final labels = graphHistory
        .map((h) => '${h['month'] ?? ''}月')
        .toList();

    if (!mounted) return;
    setState(() {
      _total = total;
      _prevTotal = prevTotal;
      _startTotal = startTotal;
      _categories = categories;
      _graphPoints = points;
      _graphLabels = labels;
      _fiscalStartMonth = fiscalStartMonth;
      _yearSellProfit = yearTotals.profitTotal;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'ホーム',
          style: Theme.of(context)
              .textTheme
              .titleLarge!
              .copyWith(fontWeight: AppFont.semibold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'お知らせ',
            onPressed: () {
              // TODO: お知らせ画面へ
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Theme.of(context).dividerColor),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                children: [
                  _buildTotalCard(),
                  const SizedBox(height: 16),
                  _buildRatioProfitCard(),
                  const SizedBox(height: 16),
                  _buildSellProfitCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({
    required String title,
    required Widget child,
    Widget? trailing,
    Widget? titleSuffix,
    double titleSpacing = 6,
  }) {
    final titleText = Text(
      title,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: AppFont.semibold,
            letterSpacing: 0.5,
          ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.lgAll,
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trailing != null || titleSuffix != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                titleText,
                if (titleSuffix != null) ...[
                  const SizedBox(width: 8),
                  titleSuffix,
                ],
                if (trailing != null) ...[
                  const Spacer(),
                  trailing,
                ],
              ],
            )
          else
            titleText,
          SizedBox(height: titleSpacing),
          child,
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    final compBase = _isYearComparison ? _startTotal : _prevTotal;
    final compLabel = _isYearComparison ? '年初比' : '前月比';
    final diff = _total - compBase;
    final diffRate = compBase > 0 ? (_total / compBase - 1) * 100 : 0.0;
    final hasComp = compBase > 0;

    return _buildCard(
      title: '総資産',
      titleSpacing: 0,
      trailing: _ComparisonToggle(
        isYearComparison: _isYearComparison,
        onChanged: (v) => setState(() => _isYearComparison = v),
      ),
      child: GestureDetector(
        onTap: _toggleHideTotal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.hideTotalNotifier.value ? '¥••••••' : formatYen(_total),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: AppFont.title1,
                    fontWeight: AppFont.bold,
                    letterSpacing: -0.5,
                    fontFeatures: AppFont.tabular,
                  ),
            ),
            if (hasComp) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$compLabel ${formatYen(diff, signed: true)}'
                ' (${diffRate >= 0 ? '+' : ''}${diffRate.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: AppFont.footnote,
                  color: context.colors.diff(diff),
                  fontFeatures: AppFont.tabular,
                ),
              ),
            ],
            if (_graphPoints.length >= 2) ...[
              const SizedBox(height: 20),
              AssetLineChart(
                points: _graphPoints,
                labels: _graphLabels,
                height: 130,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatioProfitCard() {
    if (_categories.isEmpty) {
      return _buildCard(
        title: '資産比率',
        child: SizedBox(
          height: 80,
          child: Center(
            child: Text('資産データがありません', style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
      );
    }

    final grandTotal = _categories.fold<int>(0, (s, c) => s + c.currentTotal);
    final useYear = _isYearComparison;
    final hasBase = useYear ? _startTotal > 0 : _prevTotal > 0;
    final label = useYear ? '年初比' : '前月比';

    final titleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: AppFont.semibold,
          letterSpacing: 0.5,
        );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.lgAll,
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('資産比率', style: titleStyle),
              const Spacer(),
              // 凡例の増減列の見出し（合計は総資産カードに表示済みなので出さない）
              if (hasBase)
                Text(
                  '$labelの増減',
                  style: titleStyle?.copyWith(
                    fontWeight: AppFont.regular,
                    color: context.colors.tertiaryLabel,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex =
                              response.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sections: [
                      for (int i = 0; i < _categories.length; i++) ...[
                        () {
                          final pct = grandTotal > 0
                              ? (_categories[i].currentTotal / grandTotal * 100)
                                  .round()
                              : 0;
                          return PieChartSectionData(
                            value: _categories[i].currentTotal.toDouble(),
                            color: _chartColors[i % _chartColors.length],
                            radius: _touchedIndex == i ? 60 : 52,
                            title: pct >= 8 ? '$pct%' : '',
                            titleStyle: const TextStyle(
                              fontSize: AppFont.caption2,
                              fontWeight: AppFont.bold,
                              color: Colors.white,
                            ),
                          );
                        }(),
                      ],
                    ],
                    centerSpaceRadius: 20,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xs),
                    for (int i = 0; i < _categories.length; i++) ...[
                      _LegendItem(
                        color: _chartColors[i % _chartColors.length],
                        label: _categories[i].name,
                        diff: hasBase
                            ? (useYear
                                ? _categories[i].currentTotal -
                                    _categories[i].startTotal
                                : _categories[i].currentTotal -
                                    _categories[i].prevTotal)
                            : null,
                      ),
                      if (i < _categories.length - 1)
                        const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSellProfitCard() {
    final now = DateTime.now();
    final fyStartYear = now.month >= _fiscalStartMonth ? now.year : now.year - 1;
    final from = DateTime(fyStartYear, _fiscalStartMonth);
    final months = <(int, int)>[];
    var cursor = from;
    while (!cursor.isAfter(now)) {
      months.add((cursor.year, cursor.month));
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    final categoryColors = {
      for (int i = 0; i < _categories.length; i++)
        _categories[i].id: _chartColors[i % _chartColors.length],
    };
    final categoryColorsByName = {
      for (int i = 0; i < _categories.length; i++)
        _categories[i].name: _chartColors[i % _chartColors.length],
    };

    return _buildCard(
      title: '売却損益',
      titleSpacing: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '年計',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
              Text(
                _yearSellProfit == 0
                    ? '—'
                    : formatYen(_yearSellProfit, signed: true),
                style: TextStyle(
                  fontSize: AppFont.title3,
                  fontWeight: AppFont.bold,
                  letterSpacing: -0.5,
                  fontFeatures: AppFont.tabular,
                  color: _yearSellProfit > 0
                      ? context.colors.positive
                      : _yearSellProfit < 0
                          ? context.colors.negative
                          : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            child: SellProfitBarChart(
              months: months,
              refreshKey: 0,
              categoryColors: categoryColors,
              categoryColorsByName: categoryColorsByName,
            ),
          ),
        ],
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
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.smAll,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: AppRadius.smAll,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppFont.caption1,
            fontWeight: isActive ? AppFont.semibold : AppFont.regular,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.diff,
  });

  final Color color;
  final String label;
  final int? diff;

  @override
  Widget build(BuildContext context) {
    final diffVal = diff;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (diffVal != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            formatYen(diffVal, signed: true),
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: AppFont.caption1,
              fontWeight: AppFont.semibold,
              color: context.colors.diff(diffVal),
              fontFeatures: AppFont.tabular,
            ),
          ),
        ],
      ],
    );
  }
}
