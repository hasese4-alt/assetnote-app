import 'package:asset_note/pages/assets_list_body.dart';
import 'package:asset_note/pages/edit_asset_page.dart';
import 'package:asset_note/pages/edit_history_asset_page.dart';
import 'package:asset_note/pages/real_estate_detail_page.dart';
import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/utils/asset_history_math.dart';
import 'package:asset_note/utils/category_favicon.dart';
import 'package:asset_note/viewmodels/assets_view_model.dart';
import 'package:asset_note/widgets/asset_card_widget.dart';
import 'package:asset_note/widgets/assets_month_selector_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssetsListPage extends StatefulWidget {
  final ValueNotifier<int> refreshNotifier;
  final ValueNotifier<bool> hideTotalNotifier;
  final ValueNotifier<(int, int)>? addMonthNotifier;

  const AssetsListPage({super.key, required this.refreshNotifier, required this.hideTotalNotifier, this.addMonthNotifier});

  @override
  State<AssetsListPage> createState() => _AssetsListPageState();
}

class _AssetsListPageState extends State<AssetsListPage> {
  late final AssetsRepository _repository;

  int viewYear = DateTime.now().year;
  int viewMonth = DateTime.now().month;
  int total = 0;
  bool isConfirmed = false;
  bool isInitialLoading = true;
  bool _isProcessing = false;
  int goalAmount = 0;
  bool isYearComparison = true;
  Map<String, bool> monthlyLock = {};
  List<Map<String, dynamic>> assets = [];

  // assetsテーブルが実際に表す月。確定時のみ前進し、確定解除では変わらない。
  // SharedPreferences で永続管理し、ロック状態だけから推測しない。
  int _editingYear = DateTime.now().year;
  int _editingMonth = DateTime.now().month;

  String? _selectedCategory1Id;

  final ScrollController _monthScrollController = ScrollController();
  final NumberFormat _formatter = NumberFormat('#,###');

  late Future<List<Map<String, dynamic>>> _startOfYearHistoryFuture;
  late Future<List<Map<String, dynamic>>> _previousMonthHistoryFuture;

  // assetsテーブルが実際に表す月と一致するか（編集可能な月か）
  bool get _isActiveMonth => viewYear == _editingYear && viewMonth == _editingMonth;

  // SharedPreferencesがない初回起動用: ロック状態から編集月を推定する
  DateTime _inferEditingMonthFromLocks() {
    final now = DateTime.now();
    DateTime? latestConfirmed;
    for (final entry in monthlyLock.entries) {
      if (!entry.value) continue;
      final parts = entry.key.split('-');
      final d = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      if (latestConfirmed == null || d.isAfter(latestConfirmed)) {
        latestConfirmed = d;
      }
    }
    if (latestConfirmed == null) return DateTime(now.year, now.month);
    final next = DateTime(latestConfirmed.year, latestConfirmed.month + 1);
    final today = DateTime(now.year, now.month);
    return next.isAfter(today) ? today : next;
  }

  @override
  void initState() {
    super.initState();
    _repository = AssetsRepository(Supabase.instance.client);
    _reloadFutures();
    _loadPreferences();
    _initializePage();
    widget.refreshNotifier.addListener(_onRefresh);
    widget.hideTotalNotifier.addListener(_onHideTotalChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrentMonth());
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_onRefresh);
    widget.hideTotalNotifier.removeListener(_onHideTotalChanged);
    _monthScrollController.dispose();
    super.dispose();
  }

  void _onHideTotalChanged() {
    if (mounted) setState(() {});
  }

  void _onRefresh() {
    _loadPreferences();
    loadAllMonthlyLocks();
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
    });
  }

  Future<void> _initializePage() async {
    // ① 先に全月ロック状態を取得
    try {
      await loadAllMonthlyLocks();
    } catch (_) {}

    // ② 編集月（assetsテーブルが実際に表す月）を SharedPreferences から復元
    //    保存値がなければロック状態から推定して保存する
    final prefs = await SharedPreferences.getInstance();
    final savedYear  = prefs.getInt('editing_year');
    final savedMonth = prefs.getInt('editing_month');
    final now = DateTime.now();

    int ey, em;
    if (savedYear != null && savedMonth != null) {
      ey = savedYear;
      em = savedMonth;
    } else {
      // 初回: ロック状態から推定
      final inferred = _inferEditingMonthFromLocks();
      ey = inferred.year;
      em = inferred.month;
    }

    // 確定済みの月が編集月になっている場合は翌月に補正
    // （確定処理が途中で失敗した場合などに発生する）
    while (isMonthConfirmed(ey, em)) {
      final next = DateTime(ey, em + 1);
      ey = next.year;
      em = next.month;
    }

    if (mounted) setState(() { _editingYear = ey; _editingMonth = em; });
    await prefs.setInt('editing_year',  _editingYear);
    await prefs.setInt('editing_month', _editingMonth);
    _updateAddMonth(); // SharedPreferences 復元・補正後に通知を更新

    // ③ 今日の月を表示中かつ編集月が異なる場合は編集月へ移動
    //    例: 7月未確定のまま8月になった → 自動で7月ビューに切り替え
    if (viewYear == now.year && viewMonth == now.month &&
        (viewYear != _editingYear || viewMonth != _editingMonth)) {
      if (mounted) {
        setState(() {
          viewYear = _editingYear;
          viewMonth = _editingMonth;
          _selectedCategory1Id = null;
        });
      }
      _scrollToMonth(_editingYear, _editingMonth);
      _reloadFutures();
    }

    // ④ 現在表示月の確定状態を取得
    try {
      await loadMonthlyLock();
    } catch (_) {}

    // ⑤ 資産を取得（_isActiveMonth が正しく確定してから）
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
    _updateAddMonth();
  }

  bool isMonthConfirmed(int year, int month) {
    return monthlyLock['$year-${month.toString().padLeft(2, '0')}'] ?? false;
  }

  void _updateAddMonth() {
    if (widget.addMonthNotifier == null) return;
    widget.addMonthNotifier!.value = (_editingYear, _editingMonth);
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
      final data = _isActiveMonth
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

  Future<void> _deleteHistoryAsset(int historyId) async {
    await _repository.deleteHistoryRow(historyId);
    await fetchAssets();
  }

  Future<void> _copyAsset(Map<String, dynamic> a) async {
    await _repository.insertAsset(
      name: a['name'] as String? ?? '',
      value: a['value'] as int? ?? 0,
      category1Id: a['category1_id'] as String?,
      category2Id: a['category2_id'] as String?,
      acquisitionPrice: AssetHistoryMath.coerceInt(a['acquisition_price']),
      iconLabel: a['icon_label'] as String?,
      iconTextColor: a['icon_text_color'] as String?,
      iconBgColor: a['icon_bg_color'] as String?,
      hideFavicon: a['hide_favicon'] as bool? ?? false,
    );
    await fetchAssets();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('資産を複製しました。')),
      );
    }
  }

  Future<void> handleConfirmToggle() async {
    final newValue = !isConfirmed;

    if (newValue) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('この月を確定'),
          content: Text(
            '$viewYear年$viewMonth月を確定します。\n'
            '確定するとスナップショットが保存され、翌月にデータが引き継がれます。\n\n'
            '確定後に未確定に戻すことも可能です。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.primary,
              ),
              child: const Text('確定'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _isProcessing = true);
    try {
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
            forceCurrentAssets: _isActiveMonth,
          );
          await _repository.copySnapshotToNextMonth(fromYear: viewYear, fromMonth: viewMonth);
          await _repository.deleteSoldAssetsForMonth(year: viewYear, month: viewMonth);

          final next = DateTime(viewYear, viewMonth + 1);
          // 確定時のみ編集月を前進させ SharedPreferences に保存
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('editing_year',  next.year);
          await prefs.setInt('editing_month', next.month);
          setState(() {
            isConfirmed = true;
            viewYear = next.year;
            viewMonth = next.month;
            _editingYear  = next.year;
            _editingMonth = next.month;
          });
          _scrollToMonth(next.year, next.month);
          _reloadFutures();
          await loadMonthlyLock();
          await loadAllMonthlyLocks(); // _updateAddMonth はここで呼ばれる
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

      // 確定解除: assetsテーブル（編集月）は変えない。ロック状態のみ更新。
      // 確定解除した月の売却済み資産は assets_history のスナップショットに is_sold=true
      // として残っているため、そちらから表示される（assets テーブルへの復元は不要）。
      setState(() => isConfirmed = false);
      await loadAllMonthlyLocks();
      await fetchAssets();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> handleResetMonth() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('この月をリセット'),
        content: Text(
          _isActiveMonth
              ? '$viewYear年$viewMonth月の売却・変更をすべて取り消し、前月末の状態に戻します。'
                  '\n当月の売却メモも削除されます。\n\nこの操作は元に戻せません。'
              : '$viewYear年$viewMonth月のスナップショットと確定状態を削除し、'
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

    setState(() => _isProcessing = true);
    try {
      await _repository.resetMonthData(
        year: viewYear,
        month: viewMonth,
        isCurrentMonth: _isActiveMonth,
      );
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
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _onYearComparisonChanged(bool useYearOverYear) async {
    setState(() => isYearComparison = useYearOverYear);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isYearComparison', useYearOverYear);
  }

  Future<void> _toggleHideTotal() async {
    widget.hideTotalNotifier.value = !widget.hideTotalNotifier.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideTotal', widget.hideTotalNotifier.value);
  }

  Widget _buildAssetCard(Map<String, dynamic> a, Map<int, int> startByAssetId, {bool isGrouped = false, bool isNewThisMonth = false}) {
    final aid = AssetHistoryMath.coerceInt(a['asset_id']) ??
        AssetHistoryMath.coerceInt(a['id']);
    final start = aid != null ? startByAssetId[aid] : null;

    // スナップショット未収録の場合は取得価格を比較基準にする
    final acqPrice = AssetHistoryMath.coerceInt(a['acquisition_price']);
    final effectiveStart = start ?? acqPrice;

    return AssetCardWidget(
      asset: a,
      isConfirmed: isConfirmed,
      isCurrentMonth: _isActiveMonth,
      formatter: _formatter,
      startOfYearValue: effectiveStart,
      isGrouped: isGrouped,
      isNewThisMonth: isNewThisMonth,
      onEditCurrent: () async {
        if (aid != null) {
          final reDetails = await _repository.fetchRealEstateDetails(aid);
          if (reDetails != null && mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RealEstateDetailPage(
                  assetId: aid,
                  assetName: a['name'] as String? ?? '',
                ),
              ),
            );
            await fetchAssets();
            return;
          }
        }
        if (!mounted) return;
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
        if (_isActiveMonth) {
          final id = AssetHistoryMath.coerceInt(a['id']);
          if (id != null) deleteAsset(id);
        } else {
          final historyId = AssetHistoryMath.coerceInt(a['id']);
          if (historyId != null) _deleteHistoryAsset(historyId);
        }
      },
      onUnsell: () => _showUnsellSheet(a),
      onCopy: _isActiveMonth ? () => _copyAsset(a) : null,
    );
  }

  Future<void> _showUnsellSheet(Map<String, dynamic> asset) async {
    final acqPrice = AssetHistoryMath.coerceInt(asset['acquisition_price']);
    final assetId = AssetHistoryMath.coerceInt(asset['id']);
    if (assetId == null) return;

    final unsold = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UnsellSheet(
        assetName: asset['name'] as String? ?? '',
        acquisitionPrice: acqPrice,
        onConfirm: (restoredValue) => _repository.unsellAsset(
          assetId: assetId,
          restoredValue: restoredValue,
        ),
      ),
    );

    if (unsold == true && mounted) await fetchAssets();
  }

  List<Map<String, dynamic>> _extractCategories(List<Map<String, dynamic>> assets) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final a in assets) {
      final id = a['category1_id'] as String?;
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      final name = a['categories1']?['name'] as String?
          ?? a['category1_name'] as String?
          ?? '未分類';
      final icon = a['categories1']?['icon'] as String?;
      result.add({'id': id, 'name': name, 'icon': icon});
    }
    return result;
  }

  Widget _buildCategoryChipsRow(
    BuildContext context,
    List<Map<String, dynamic>> categories,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _CategoryChip(
            label: 'すべて',
            isSelected: _selectedCategory1Id == null,
            onTap: () => setState(() => _selectedCategory1Id = null),
          ),
          ...categories.map((cat) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _CategoryChip(
              label: cat['name'] as String,
              iconKey: cat['icon'] as String?,
              isSelected: _selectedCategory1Id == cat['id'],
              onTap: () => setState(() => _selectedCategory1Id = cat['id'] as String),
            ),
          )),
        ],
      ),
    );
  }

  void _showPageInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('資産一覧について'),
        content: const Text(
          '・月セレクターで表示月を切り替えられます。\n'
          '・当月は資産の追加・編集・削除が可能です。\n'
          '・月を確定するとスナップショットが保存され、翌月にデータが引き継がれます。\n'
          '・確定後も未確定に戻すことができます。\n'
          '・カテゴリチップで絞り込み表示ができます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedAssets = List<Map<String, dynamic>>.from(assets)
      ..sort((a, b) => (b['value'] ?? 0).compareTo(a['value'] ?? 0));

    final availableCategories = _extractCategories(sortedAssets);

    final filteredAssets = _selectedCategory1Id == null
        ? sortedAssets
        : sortedAssets.where((a) => a['category1_id'] == _selectedCategory1Id).toList();

    final groupedDisplay = AssetsViewModel.groupForDisplay(filteredAssets);
    final vmTotal = AssetsViewModel.total(sortedAssets);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFF000000),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          '資産一覧',
          style: Theme.of(context)
              .textTheme
              .titleLarge!
              .copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '画面の説明',
            onPressed: _showPageInfo,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Theme.of(context).dividerColor),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: AssetsMonthSelectorStrip(
              scrollController: _monthScrollController,
              viewYear: viewYear,
              viewMonth: viewMonth,
              isMonthConfirmed: isMonthConfirmed,
              onMonthTap: (year, month) async {
                setState(() {
                  viewYear = year;
                  viewMonth = month;
                  _selectedCategory1Id = null;
                });
                _scrollToMonth(year, month);
                _reloadFutures();
                await loadMonthlyLock();
                await fetchAssets();
              },
              onConfirmTap: handleConfirmToggle,
              isConfirmed: isConfirmed,
              isProcessing: _isProcessing,
              stripEnd: _stripEnd,
              onResetLongPress: handleResetMonth,
            ),
          ),
          Container(height: 1, color: Theme.of(context).dividerColor),
          if (availableCategories.isNotEmpty)
            _buildCategoryChipsRow(context, availableCategories),
          if (availableCategories.isNotEmpty)
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
                      isCurrentMonth: _isActiveMonth,
                      hideTotal: widget.hideTotalNotifier.value,
                      formatter: _formatter,
                      goalAmount: goalAmount,
                      isInitialLoading: isInitialLoading,
                      isConfirmed: isConfirmed,
                      vmTotal: vmTotal,
                      onToggleHideTotal: _toggleHideTotal,
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.iconKey,
  });

  final String label;
  final String? iconKey;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconData = iconKey != null ? categoryIconDataForKey(iconKey) : null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconData != null) ...[
              Icon(
                iconData,
                size: 13,
                color: isSelected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isSelected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.6),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsellSheet extends StatefulWidget {
  const _UnsellSheet({
    required this.assetName,
    this.acquisitionPrice,
    required this.onConfirm,
  });

  final String assetName;
  final int? acquisitionPrice;
  final Future<void> Function(int restoredValue) onConfirm;

  @override
  State<_UnsellSheet> createState() => _UnsellSheetState();
}

class _UnsellSheetState extends State<_UnsellSheet> {
  late final TextEditingController _controller;
  bool _submitting = false;

  int? get _restoredValue => int.tryParse(_controller.text);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.acquisitionPrice?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final v = _restoredValue;
    if (v == null) return;
    setState(() => _submitting = true);
    await widget.onConfirm(v);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final separatorColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
    final secondaryLabel = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73);
    final fmt = NumberFormat('#,###', 'ja_JP');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.assetName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (widget.acquisitionPrice != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('取得価格',
                              style: TextStyle(
                                  color: secondaryLabel, fontSize: 15)),
                          Text(
                            '¥${fmt.format(widget.acquisitionPrice)}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, indent: 16, color: separatorColor),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Text('復元価格',
                            style: TextStyle(
                                color: secondaryLabel, fontSize: 15)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '0',
                              hintStyle: TextStyle(color: secondaryLabel),
                              prefixText: '¥',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed:
                    (_restoredValue != null && !_submitting) ? _confirm : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: const StadiumBorder(),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('売却を取り消す',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
