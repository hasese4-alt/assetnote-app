import 'package:asset_note/pages/add_asset_page.dart';
import 'package:asset_note/pages/assets_list_body.dart';
import 'package:asset_note/pages/edit_asset_page.dart';
import 'package:asset_note/pages/edit_history_asset_page.dart';
import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/utils/asset_history_math.dart';
import 'package:asset_note/viewmodels/assets_view_model.dart';
import 'package:asset_note/widgets/asset_card_widget.dart';
import 'package:asset_note/widgets/assets_month_selector_strip.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssetsListPage extends StatefulWidget {
  final ValueNotifier<int> refreshNotifier;

  const AssetsListPage({super.key, required this.refreshNotifier});

  @override
  State<AssetsListPage> createState() => _AssetsListPageState();
}

class _AssetsListPageState extends State<AssetsListPage> {
  late final AssetsRepository _repository;

  int viewYear = DateTime.now().year;
  int viewMonth = DateTime.now().month;
  int total = 0;
  bool hideTotal = false;
  bool isConfirmed = false;
  bool isInitialLoading = true;
  int goalAmount = 0;
  int userAge = 30;
  bool isYearComparison = true;
  double userPercentile = 0.0;
  Map<String, bool> monthlyLock = {};
  List<Map<String, dynamic>> assets = [];

  final ScrollController _monthScrollController = ScrollController();
  final NumberFormat _formatter = NumberFormat('#,###');

  late Future<List<Map<String, dynamic>>> _startOfYearHistoryFuture;
  late Future<List<Map<String, dynamic>>> _previousMonthHistoryFuture;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return viewYear == now.year && viewMonth == now.month;
  }

  @override
  void initState() {
    super.initState();
    _repository = AssetsRepository(Supabase.instance.client);
    _reloadFutures();
    _loadPreferences();
    _initializePage();
    loadAllMonthlyLocks();
    widget.refreshNotifier.addListener(_onRefresh);

    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrentMonth());
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_onRefresh);
    _monthScrollController.dispose();
    super.dispose();
  }

  void _onRefresh() {
    _loadPreferences();
    fetchAssets();
  }

  void _reloadFutures() {
    _startOfYearHistoryFuture = _repository.fetchStartOfYearHistory(year: viewYear);
    _previousMonthHistoryFuture = _repository.fetchPreviousMonthHistory(
      year: viewYear,
      month: viewMonth,
    );
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      goalAmount = prefs.getInt('goalAmount') ?? 30_000_000;
      isYearComparison = prefs.getBool('isYearComparison') ?? true;
      hideTotal = prefs.getBool('hideTotal') ?? false;
      userAge = prefs.getInt('userAge') ?? 30;
    });
  }

  Future<void> _initializePage() async {
    try {
      await loadMonthlyLock();
    } catch (_) {}

    try {
      await fetchAssets();
    } catch (_) {}

    if (!mounted) return;
    setState(() => isInitialLoading = false);
  }

  void _jumpToCurrentMonth() {
    if (!_monthScrollController.hasClients) return;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 18);
    final index = (now.year - start.year) * 12 + (now.month - start.month);
    const itemStride = 56.0;
    const leftPadding = 20.0;
    final itemCenter = leftPadding + index * itemStride + 24.0;
    final viewportWidth = _monthScrollController.position.viewportDimension;
    final target = (itemCenter - viewportWidth / 2).clamp(
      0.0,
      _monthScrollController.position.maxScrollExtent,
    );
    _monthScrollController.jumpTo(target);
  }

  void _scrollToMonth(int year, int month) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_monthScrollController.hasClients) return;
      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 18);
      final index = (year - start.year) * 12 + (month - start.month);
      if (index < 0) return;

      const itemStride = 56.0;
      const leftPadding = 20.0;
      const itemWidth = 48.0;

      final itemLeft = leftPadding + index * itemStride;
      final itemRight = itemLeft + itemWidth;

      final scrollOffset = _monthScrollController.offset;
      final viewportWidth = _monthScrollController.position.viewportDimension;
      final maxExtent = _monthScrollController.position.maxScrollExtent;

      if (itemRight + 12 > scrollOffset + viewportWidth) {
        final target = (itemRight + 12 - viewportWidth).clamp(0.0, maxExtent);
        _monthScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else if (itemLeft - 12 < scrollOffset) {
        final target = (itemLeft - 12).clamp(0.0, maxExtent);
        _monthScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> loadAllMonthlyLocks() async {
    final rows = await _repository.fetchAllMonthlyLocks();
    final map = <String, bool>{};
    for (final row in rows) {
      final y = row['year'] as int;
      final m = row['month'] as int;
      final key = '$y-${m.toString().padLeft(2, '0')}';
      map[key] = row['confirmed'] as bool;
    }
    if (!mounted) return;
    setState(() => monthlyLock = map);
  }

  bool isMonthConfirmed(int year, int month) {
    return monthlyLock['$year-${month.toString().padLeft(2, '0')}'] ?? false;
  }

  /// 確定済みの最新月の翌月 or 今月 の大きい方を返す。
  DateTime get _stripEnd {
    final now = DateTime.now();
    DateTime? latest;
    for (final entry in monthlyLock.entries) {
      if (!entry.value) continue;
      final parts = entry.key.split('-');
      final d = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      if (latest == null || d.isAfter(latest)) latest = d;
    }
    if (latest == null) return now;
    final nextAfterConfirmed = DateTime(latest.year, latest.month + 1);
    return nextAfterConfirmed.isAfter(now) ? nextAfterConfirmed : now;
  }

  Future<void> loadMonthlyLock() async {
    try {
      final lock = await _repository.fetchMonthlyLock(year: viewYear, month: viewMonth);
      if (!mounted) return;
      setState(() => isConfirmed = lock?['confirmed'] as bool? ?? false);
    } catch (_) {
      if (!mounted) return;
      setState(() => isConfirmed = false);
    }
  }

  Future<void> fetchAssets() async {
    try {
      final snapshotDate = '$viewYear-${viewMonth.toString().padLeft(2, '0')}-01';
      final data = _isCurrentMonth
          ? await _repository.fetchCurrentAssets()
          : await _repository.fetchHistoryByDate(snapshotDate);

      if (!mounted) return;

      int sum = 0;
      for (final a in data) {
        final v = a['value'];
        if (v is int) sum += v;
        if (v is double) sum += v.toInt();
      }

      setState(() {
        assets = data;
        total = sum;
        userPercentile = AssetsViewModel.wealthPercentileForTotal(
          sum,
          ageGroup: AssetsViewModel.ageGroupForAge(userAge),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        assets = [];
        total = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('資産の読み込みに失敗しました。')),
      );
    }
  }

  Future<void> deleteAsset(int id) async {
    await _repository.deleteCurrentAsset(id);
    await fetchAssets();
  }

  Future<void> handleConfirmToggle() async {
    final newValue = !isConfirmed;

    await _repository.upsertMonthlyLock(
      year: viewYear,
      month: viewMonth,
      confirmed: newValue,
    );

    if (newValue) {
      try {
        await _repository.upsertMonthlySnapshot(
          year: viewYear,
          month: viewMonth,
          forceCurrentAssets: _isCurrentMonth,
        );
        await _repository.copySnapshotToNextMonth(fromYear: viewYear, fromMonth: viewMonth);

        final next = DateTime(viewYear, viewMonth + 1);
        setState(() {
          isConfirmed = true;
          viewYear = next.year;
          viewMonth = next.month;
        });
        _scrollToMonth(next.year, next.month);
        _reloadFutures();
        await loadMonthlyLock();
        await loadAllMonthlyLocks();
        await fetchAssets();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('月の確定に失敗しました。接続を確認してください。')),
        );
        await _repository.updateMonthlyLock(
          year: viewYear,
          month: viewMonth,
          confirmed: false,
        );
        if (!mounted) return;
        setState(() => isConfirmed = false);
      }
      return;
    }

    setState(() => isConfirmed = false);
    await loadAllMonthlyLocks();
  }

  Future<void> handleResetMonth() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('この月をリセット'),
        content: Text(
          '$viewYear年$viewMonth月のスナップショットと確定状態を削除し、'
          '前月末の状態に戻します。\n\nこの操作は元に戻せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('リセット'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repository.resetMonthData(year: viewYear, month: viewMonth);
      if (!mounted) return;
      _reloadFutures();
      await loadMonthlyLock();
      await loadAllMonthlyLocks();
      await fetchAssets();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('月のデータをリセットしました。')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('リセットに失敗しました。接続を確認してください。')),
      );
    }
  }

  Future<void> _onYearComparisonChanged(bool useYearOverYear) async {
    setState(() => isYearComparison = useYearOverYear);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isYearComparison', useYearOverYear);
  }

  Future<void> _toggleHideTotal() async {
    setState(() => hideTotal = !hideTotal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideTotal', hideTotal);
  }

  Widget _buildAssetCard(Map<String, dynamic> a, Map<int, int> startByAssetId) {
    final aid = AssetHistoryMath.coerceInt(a['asset_id']) ??
        AssetHistoryMath.coerceInt(a['id']);
    final start = aid != null ? startByAssetId[aid] : null;

    // スナップショット未収録の場合は取得価格を比較基準にする
    final acqPrice = AssetHistoryMath.coerceInt(a['acquisition_price']);
    final effectiveStart = start ?? acqPrice;

    return AssetCardWidget(
      asset: a,
      isConfirmed: isConfirmed,
      isCurrentMonth: _isCurrentMonth,
      formatter: _formatter,
      startOfYearValue: effectiveStart,
      onEditCurrent: () async {
        final updated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => EditAssetPage(asset: Map<String, dynamic>.from(a)),
          ),
        );
        if (updated == true) await fetchAssets();
      },
      onEditHistory: () async {
        final updated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => EditHistoryAssetPage(
              assetHistory: Map<String, dynamic>.from(a),
            ),
          ),
        );
        if (updated == true) await fetchAssets();
      },
      onDelete: () {
        final id = AssetHistoryMath.coerceInt(a['asset_id']) ??
            AssetHistoryMath.coerceInt(a['id']);
        if (id != null) deleteAsset(id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedAssets = List<Map<String, dynamic>>.from(assets)
      ..sort((a, b) => (b['value'] ?? 0).compareTo(a['value'] ?? 0));

    final groupedDisplay = AssetsViewModel.groupForDisplay(sortedAssets);
    final vmTotal = AssetsViewModel.total(sortedAssets);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFF000000),
      floatingActionButton: (_isCurrentMonth || !isConfirmed)
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddAssetPage(
                      year: viewYear,
                      month: viewMonth,
                    ),
                  ),
                ).then((_) {
                  if (mounted) fetchAssets();
                });
              },
              child: const Icon(Icons.add),
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'AssetNote',
          style: Theme.of(context)
              .textTheme
              .titleLarge!
              .copyWith(fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Theme.of(context).dividerColor),
        ),
      ),
      body: Column(
        children: [
          AssetsMonthSelectorStrip(
            scrollController: _monthScrollController,
            viewYear: viewYear,
            viewMonth: viewMonth,
            isMonthConfirmed: isMonthConfirmed,
            onMonthTap: (year, month) async {
              setState(() {
                viewYear = year;
                viewMonth = month;
              });
              _scrollToMonth(year, month);
              _reloadFutures();
              await loadMonthlyLock();
              await fetchAssets();
            },
            onConfirmTap: handleConfirmToggle,
            isConfirmed: isConfirmed,
            stripEnd: _stripEnd,
            onResetTap: handleResetMonth,
          ),
          Container(height: 1, color: Theme.of(context).dividerColor),
          Expanded(
            child: CustomScrollView(
              slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                sliver: SliverToBoxAdapter(
                  child: AssetsListBody(
                    startOfYearHistoryFuture: _startOfYearHistoryFuture,
                    previousMonthHistoryFuture: _previousMonthHistoryFuture,
                    sortedAssets: sortedAssets,
                    groupedDisplay: groupedDisplay,
                    isYearComparison: isYearComparison,
                    isCurrentMonth: _isCurrentMonth,
                    hideTotal: hideTotal,
                    formatter: _formatter,
                    goalAmount: goalAmount,
                    userPercentile: userPercentile,
                    ageGroup: AssetsViewModel.ageGroupForAge(userAge),
                    isInitialLoading: isInitialLoading,
                    isConfirmed: isConfirmed,
                    vmTotal: vmTotal,
                    onToggleHideTotal: _toggleHideTotal,
                    onConfirmToggle: handleConfirmToggle,
                    onYearComparisonChanged: _onYearComparisonChanged,
                    buildAssetCard: _buildAssetCard,
                  ),
                ),
              ),
            ],
            ),
          ),
        ],
      ),
    );
  }
}
