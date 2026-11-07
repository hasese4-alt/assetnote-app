import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/viewmodels/assets_view_model.dart';
import 'package:asset_note/utils/asset_history_math.dart';
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

  final _fmt = NumberFormat('#,###', 'ja_JP');

  static const _chartColors = [
    Color(0xFF2864F0),
    Color(0xFF00963C),
    Color(0xFFFFB91E),
    Color(0xFFDC1E32),
    Color(0xFF7B9FF5),
    Color(0xFF5856D6),
    Color(0xFFFA6414),
    Color(0xFF4BC87A),
  ];

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
    final results = await Future.wait<List<Map<String, dynamic>>>([
      _repo.fetchCurrentAssets(),
      _repo.fetchPreviousMonthHistory(year: now.year, month: now.month),
      _repo.fetchStartOfYearHistory(year: now.year),
      _viewModel.fetchGraphHistory(),
    ]);

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
              .copyWith(fontWeight: FontWeight.w600),
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
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
              widget.hideTotalNotifier.value ? '¥••••••' : '¥${_fmt.format(_total)}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
            ),
            if (hasComp) ...[
              const SizedBox(height: 4),
              Text(
                '$compLabel ${diff >= 0 ? '+' : ''}${_fmt.format(diff)} (${diffRate.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: 13,
                  color: diff >= 0 ? const Color(0xFF00963C) : const Color(0xFFDC1E32),
                ),
              ),
            ],
            if (_graphPoints.length >= 2) ...[
              const SizedBox(height: 20),
              AssetLineChart(
                points: _graphPoints,
                labels: _graphLabels,
                height: 100,
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
    final totalDiff = useYear ? _total - _startTotal : _total - _prevTotal;
    final hasBase = useYear ? _startTotal > 0 : _prevTotal > 0;
    final label = useYear ? '年初比' : '前月比';
    final diffColor = totalDiff >= 0 ? const Color(0xFF00963C) : const Color(0xFFDC1E32);

    final titleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
              SizedBox(
                width: 140,
                child: Text('資産比率', style: titleStyle),
              ),
              const SizedBox(width: 16),
              if (hasBase)
                Expanded(
                  child: Text(
                    label,
                    style: titleStyle?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.45),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
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
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
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
                    if (hasBase) ...[
                      Text(
                        '${totalDiff >= 0 ? '+' : ''}¥${_fmt.format(totalDiff)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: diffColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
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
                        formatter: hasBase ? _fmt : null,
                      ),
                      if (i < _categories.length - 1)
                        const SizedBox(height: 6),
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

    return _buildCard(
      title: '売却損益',
      titleSpacing: 12,
      child: RepaintBoundary(
        child: SellProfitBarChart(
          months: months,
          refreshKey: 0,
          categoryColors: categoryColors,
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
  final void Function(bool) onChanged;

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.diff,
    this.formatter,
  });

  final Color color;
  final String label;
  final int? diff;
  final NumberFormat? formatter;

  @override
  Widget build(BuildContext context) {
    final diffVal = diff;
    final diffColor = diffVal != null && diffVal >= 0
        ? const Color(0xFF00963C)
        : const Color(0xFFDC1E32);

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
        if (diffVal != null && formatter != null)
          SizedBox(
            width: 80,
            child: Text(
              '${diffVal >= 0 ? '+' : ''}¥${formatter!.format(diffVal)}',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: diffColor,
              ),
            ),
          ),
      ],
    );
  }
}
