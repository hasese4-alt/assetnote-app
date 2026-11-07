import 'package:asset_note/services/assets_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _fmt = NumberFormat('#,###', 'ja_JP');

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key, required this.refreshNotifier});

  final ValueNotifier<int> refreshNotifier;

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  int _fiscalStartMonth = 1;
  int _selectedFiscalYear = DateTime.now().year;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    widget.refreshNotifier.addListener(_onRefresh);
    _loadFiscalStartMonth();
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
    _loadFiscalStartMonth();
    setState(() => _refreshKey++);
  }

  Future<void> _loadFiscalStartMonth() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final m = prefs.getInt('fiscalYearStartMonth') ?? 1;
      setState(() {
        _fiscalStartMonth = m;
        _selectedFiscalYear = _fyYear(DateTime.now(), m);
      });
    }
  }

  /// 日付と期首月から年度の「年」を返す（例: 期首4月なら2026-04〜は2026年度）
  int _fyYear(DateTime date, int startMonth) =>
      date.month >= startMonth ? date.year : date.year - 1;

  /// 表示する年度ボタンのリスト（新しい順）
  List<int> get _availableFiscalYears {
    final current = _fyYear(DateTime.now(), _fiscalStartMonth);
    return [current, current - 1, current - 2];
  }

  /// 選択年度の月リストを新しい順（降順）で返す
  List<(int, int)> _buildMonthList() {
    final now = DateTime.now();
    final currentFyYear = _fyYear(now, _fiscalStartMonth);

    final from = DateTime(_selectedFiscalYear, _fiscalStartMonth);
    // 当年度は現在月まで、過去年度は年度末（次の期首の前月）まで
    final to = _selectedFiscalYear == currentFyYear
        ? DateTime(now.year, now.month)
        : DateTime(_selectedFiscalYear + 1, _fiscalStartMonth - 1);

    final result = <(int, int)>[];
    var cursor = to;
    while (!cursor.isBefore(from)) {
      result.add((cursor.year, cursor.month));
      cursor = DateTime(cursor.year, cursor.month - 1);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final months = _buildMonthList();

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFF000000),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            floating: false,
            centerTitle: false,
            title: Text(
              '資産台帳',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge!
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(49),
              child: Column(
                children: [
                  Container(
                    height: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: _availableFiscalYears.map((fy) {
                        final selected = _selectedFiscalYear == fy;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedFiscalYear = fy),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: selected
                                    ? cs.primary
                                    : cs.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$fy年度',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: selected
                                          ? cs.onPrimary
                                          : cs.onSurface
                                              .withValues(alpha: 0.6),
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _AnnualSummaryCard(
                key: ValueKey('annual-$_refreshKey-$_selectedFiscalYear'),
                months: months,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '取引履歴',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: _MonthSection(
                    key: ValueKey('$_refreshKey-${months[index].$1}-${months[index].$2}'),
                    year: months[index].$1,
                    month: months[index].$2,
                  ),
                ),
                childCount: months.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnualSummaryCard extends StatefulWidget {
  const _AnnualSummaryCard({super.key, required this.months});
  final List<(int, int)> months;

  @override
  State<_AnnualSummaryCard> createState() => _AnnualSummaryCardState();
}

class _AnnualSummaryCardState extends State<_AnnualSummaryCard> {
  late final AssetsRepository _repository;
  late Future<({
    int acquisitionTotal,
    int sellTotal,
    int profitTotal,
    List<Map<String, dynamic>> profitByCategory,
  })> _future;

  @override
  void initState() {
    super.initState();
    _repository = AssetsRepository(Supabase.instance.client);
    _future = _repository.fetchFiscalYearTotals(months: widget.months);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        final loading = !snapshot.hasData;
        final data = snapshot.data;

        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              // 取得合計 | 売却合計
              IntrinsicHeight(
                child: Row(
                  children: [
                    _SummaryCell(
                      label: '年度取得合計',
                      value: loading ? null : data!.acquisitionTotal,
                    ),
                    VerticalDivider(
                        width: 1, color: cs.outline.withValues(alpha: 0.15)),
                    _SummaryCell(
                      label: '年度売却合計',
                      value: loading ? null : data!.sellTotal,
                    ),
                  ],
                ),
              ),

              // 収益合計
              Divider(height: 1, color: cs.outline.withValues(alpha: 0.15)),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '年度収益合計',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                    ),
                    if (loading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    else
                      Text(
                        data!.profitTotal == 0
                            ? '—'
                            : '${data.profitTotal >= 0 ? "+" : ""}¥${_fmt.format(data.profitTotal.abs())}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: data.profitTotal == 0
                                  ? null
                                  : data.profitTotal > 0
                                      ? Colors.green
                                      : Colors.red,
                            ),
                      ),
                  ],
                ),
              ),

              // カテゴリ別内訳
              if (!loading && data!.profitByCategory.isNotEmpty) ...[
                Divider(height: 1, color: cs.outline.withValues(alpha: 0.15)),
                ...data.profitByCategory.map((cat) {
                  final profit = cat['profit'] as int;
                  final isGain = profit >= 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cat['category1_name'] as String,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.65),
                              ),
                        ),
                        Text(
                          '${isGain ? "+" : ""}¥${_fmt.format(profit.abs())}',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isGain ? Colors.green : Colors.red,
                              ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 4),
            value == null
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                : Text(
                    value == 0 ? '—' : '¥${_fmt.format(value!)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
          ],
        ),
      ),
    );
  }
}

class _MonthSection extends StatefulWidget {
  const _MonthSection({super.key, required this.year, required this.month});

  final int year;
  final int month;

  @override
  State<_MonthSection> createState() => _MonthSectionState();
}

class _MonthSectionState extends State<_MonthSection>
    with AutomaticKeepAliveClientMixin {
  late final AssetsRepository _repository;

  List<Map<String, dynamic>> _assets = [];
  bool _hasPrevHistory = false;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return widget.year == now.year && widget.month == now.month;
  }

  List<Map<String, dynamic>> get _newAssets => _hasPrevHistory
      ? _assets
          .where(
              (a) => a['_is_income_entry'] != true && a['_prev_value'] == null)
          .toList()
      : [];

  List<Map<String, dynamic>> get _soldEntries => _assets
      .where((a) =>
          a['_is_income_entry'] == true &&
          (a['name'] as String?)?.startsWith('売却:') == true)
      .toList();

  int get _sellProfit =>
      _soldEntries.fold(0, (sum, a) => sum + (a['_diff'] as int? ?? 0));

  int get _totalAcquisition => _newAssets.fold(0, (sum, a) {
        final acq = a['acquisition_price'] as num?;
        return sum + (acq?.toInt() ?? (a['_value'] as int? ?? 0));
      });

  int get _totalSellAmount => _soldEntries.fold(
        0, (sum, a) => sum + ((a['_sell_price'] as int?) ?? 0));

  @override
  void initState() {
    super.initState();
    _repository = AssetsRepository(Supabase.instance.client);
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final snapshotDate =
          '${widget.year}-${widget.month.toString().padLeft(2, '0')}-01';

      final List<Map<String, dynamic>> rawAssets = _isCurrentMonth
          ? await _repository.fetchCurrentAssets()
          : await _repository.fetchHistoryByDate(snapshotDate);

      final prevHistory = await _repository.fetchPreviousMonthHistory(
        year: widget.year,
        month: widget.month,
      );

      final prevMap = <int, int>{};
      for (final a in prevHistory) {
        final id = (a['asset_id'] as num).toInt();
        prevMap[id] = (a['value'] as num).toInt();
      }
      final hasPrevHistory = prevHistory.isNotEmpty;

      final normalized = rawAssets.map((a) {
        final assetId = _isCurrentMonth
            ? (a['id'] is int ? a['id'] as int : (a['id'] as num).toInt())
            : (a['asset_id'] is int
                ? a['asset_id'] as int
                : (a['asset_id'] as num).toInt());
        final value = (a['value'] as num).toInt();
        final prevValue = prevMap[assetId];
        return {
          ...a,
          '_asset_id': assetId,
          '_value': value,
          '_prev_value': prevValue,
          '_diff': value - (prevValue ?? 0),
        };
      }).toList();

      final incomeMemos = await _repository.fetchIncomeMemosForMonth(
        year: widget.year,
        month: widget.month,
      );
      for (final m in incomeMemos) {
        final memoId = (m['id'] as num).toInt();
        final amount = (m['amount'] as num?)?.toInt() ?? 0;
        final dir = m['direction'] as String?;
        final signedAmount = dir == '出' ? -amount : amount;
        final sellPrice = m['sell_price'] as int?;
        if (signedAmount == 0 && sellPrice == null) continue;
        normalized.add({
          '_asset_id': -memoId,
          '_value': 0,
          '_prev_value': null,
          '_diff': signedAmount,
          'name': m['memo'] as String? ?? '収益',
          '_is_income_entry': true,
          'asset_id': m['asset_id'] != null ? (m['asset_id'] as num).toInt() : null,
          '_sell_price': sellPrice,
        });
      }

      if (!mounted) return;
      setState(() {
        _assets = normalized;
        _hasPrevHistory = hasPrevHistory;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return _LedgerCard(
      year: widget.year,
      month: widget.month,
      newAssets: _newAssets,
      soldEntries: _soldEntries,
      sellProfit: _sellProfit,
      totalAcquisition: _totalAcquisition,
      totalSellAmount: _totalSellAmount,
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({
    required this.year,
    required this.month,
    required this.newAssets,
    required this.soldEntries,
    required this.sellProfit,
    required this.totalAcquisition,
    required this.totalSellAmount,
  });

  final int year;
  final int month;
  final List<Map<String, dynamic>> newAssets;
  final List<Map<String, dynamic>> soldEntries;
  final int sellProfit;
  final int totalAcquisition;
  final int totalSellAmount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasData = newAssets.isNotEmpty || soldEntries.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            '$year年$month月',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),

        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              // カラムヘッダー
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Text(
                          '取得',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.45),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                        ),
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      color: cs.outline.withValues(alpha: 0.15),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Text(
                          '売却',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.45),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outline.withValues(alpha: 0.15)),

              // ボディ
              if (!hasData)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 24, horizontal: 16),
                  child: Center(
                    child: Text(
                      'この月の取引はありません',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.35),
                          ),
                    ),
                  ),
                )
              else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: newAssets.isEmpty
                            ? const _EmptyColumn()
                            : Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: newAssets
                                    .map((a) => _AcquisitionRow(asset: a))
                                    .toList(),
                              ),
                      ),
                      VerticalDivider(
                        width: 1,
                        color: cs.outline.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: soldEntries.isEmpty
                            ? const _EmptyColumn()
                            : Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: soldEntries
                                    .map((a) => _SellRow(entry: a))
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
                ),

              if (hasData) ...[
                Divider(height: 1, color: cs.outline.withValues(alpha: 0.15)),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '取得  ${newAssets.length}件',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: cs.onSurface.withValues(alpha: 0.5),
                                    ),
                              ),
                              if (newAssets.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '¥${_fmt.format(totalAcquisition)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        color: cs.outline.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '売却  ${soldEntries.length}件',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: cs.onSurface.withValues(alpha: 0.5),
                                    ),
                              ),
                              if (soldEntries.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '¥${_fmt.format(totalSellAmount)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${sellProfit >= 0 ? "+" : ""}¥${_fmt.format(sellProfit.abs())}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: sellProfit >= 0
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Text(
        '— なし —',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
      ),
    );
  }
}

class _AcquisitionRow extends StatelessWidget {
  const _AcquisitionRow({required this.asset});

  final Map<String, dynamic> asset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = asset['name'] as String? ?? '不明';
    final acqPrice = (asset['acquisition_price'] as num?)?.toInt();
    final value = asset['_value'] as int? ?? 0;
    final displayAmount = acqPrice ?? value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            acqPrice != null
                ? '取得 ¥${_fmt.format(displayAmount)}'
                : '¥${_fmt.format(displayAmount)}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
          ),
        ],
      ),
    );
  }
}

class _SellRow extends StatelessWidget {
  const _SellRow({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final diff = entry['_diff'] as int? ?? 0;
    final isGain = diff >= 0;
    final rawName = entry['name'] as String? ?? '売却';
    final name =
        rawName.startsWith('売却: ') ? rawName.substring(4) : rawName;
    final sellPrice = entry['_sell_price'] as int?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          if (sellPrice != null)
            Text(
              '売却額 ¥${_fmt.format(sellPrice)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
            ),
          if (diff != 0) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  isGain ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 11,
                  color: isGain ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 2),
                Text(
                  '¥${_fmt.format(diff.abs())}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isGain ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
