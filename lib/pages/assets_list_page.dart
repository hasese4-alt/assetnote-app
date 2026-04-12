import 'package:asset_note/pages/add_asset_page.dart';
import 'package:asset_note/pages/assets_list_body.dart';
import 'package:asset_note/pages/category_settings_page.dart';
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
  const AssetsListPage({super.key});

  @override
  State<AssetsListPage> createState() => _AssetsListPageState();
}

class _AssetsListPageState extends State<AssetsListPage> {
  late final AssetsRepository repository;
  int viewYear = DateTime.now().year;
  int viewMonth = DateTime.now().month;
  int total = 0;
  bool hideTotal = false;
  bool isConfirmed = false;
  bool isInitialLoading = true;
  int goalAmount = 0;
  late PageController cardController;

  double userPercentile = 0.20;

  void updateUserPercentile() {
    setState(() {
      userPercentile = AssetsViewModel.wealthPercentileForTotal(total);
    });
  }

  Map<String, bool> monthlyLock = {};

  Future<void> loadAllMonthlyLocks() async {
    final rows = await repository.fetchAllMonthlyLocks();
    final map = <String, bool>{};

    for (final row in rows) {
      final y = row['year'] as int;
      final m = row['month'] as int;
      final c = row['confirmed'] as bool;

      final key = '$y-${m.toString().padLeft(2, '0')}';
      map[key] = c;
    }

    setState(() {
      monthlyLock = map;
    });
  }

  bool isMonthConfirmed(int year, int month) {
    final key = '$year-${month.toString().padLeft(2, '0')}';
    return monthlyLock[key] ?? false;
  }

  void _jumpToCurrentMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 18);
    final index = (now.year - start.year) * 12 + (now.month - start.month);
    const itemWidth = 80.0;
    monthScrollController.jumpTo(index * itemWidth);
  }

  final ScrollController monthScrollController = ScrollController();

  bool isYearComparison = true;

  late Future<List<Map<String, dynamic>>> _startOfYearHistoryFuture;
  late Future<List<Map<String, dynamic>>> _previousMonthHistoryFuture;

  void _reloadComparisonFutures() {
    _startOfYearHistoryFuture =
        repository.fetchStartOfYearHistory(year: viewYear);
    _previousMonthHistoryFuture = repository.fetchPreviousMonthHistory(
      year: viewYear,
      month: viewMonth,
    );
  }

  bool get isCurrentMonth {
    final now = DateTime.now();
    return viewYear == now.year && viewMonth == now.month;
  }

  List<Map<String, dynamic>> assets = [];
  final formatter = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    viewYear = now.year;
    viewMonth = now.month;

    repository = AssetsRepository(Supabase.instance.client);
    cardController = PageController(viewportFraction: 0.92);
    _reloadComparisonFutures();

    _loadGoalAmount();
    _initializePage();
    _loadComparisonMode();
    _loadHideTotal();
    loadAllMonthlyLocks();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToCurrentMonth();
    });
  }

  @override
  void dispose() {
    monthScrollController.dispose();
    cardController.dispose();
    super.dispose();
  }

  Future<void> _loadGoalAmount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      goalAmount = prefs.getInt('goalAmount') ?? 30_000_000;
    });
  }

  Future<void> _loadComparisonMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isYearComparison = prefs.getBool('isYearComparison') ?? true;
    });
  }

  Future<void> _loadHideTotal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hideTotal = prefs.getBool('hideTotal') ?? false;
    });
  }

  Future<void> _initializePage() async {
    try {
      await loadMonthlyLock();
    } catch (_) {}

    try {
      await fetchAssets();
    } finally {
      if (!mounted) return;
      setState(() {
        isInitialLoading = false;
      });
    }
  }

  Future<void> loadMonthlyLock() async {
    try {
      final lock = await repository.fetchMonthlyLock(
        year: viewYear,
        month: viewMonth,
      );

      if (!mounted) return;
      setState(() {
        isConfirmed = (lock != null ? lock['confirmed'] as bool : false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isConfirmed = false;
      });
    }
  }

  Future<void> fetchAssets() async {
    try {
      assets = [];

      final snapshotDate =
          '$viewYear-${viewMonth.toString().padLeft(2, '0')}-01';

      List<Map<String, dynamic>> data;

      if (isCurrentMonth) {
        data = await repository.fetchCurrentAssets();
      } else {
        data = await repository.fetchHistoryByDate(snapshotDate);
      }

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

      updateUserPercentile();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        assets = [];
        total = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load assets.')),
      );
    }
  }

  Future<void> deleteAsset(int id) async {
    await repository.deleteCurrentAsset(id);
    await fetchAssets();
  }

  Future<void> handleConfirmToggle() async {
    final newValue = !isConfirmed;

    await repository.upsertMonthlyLock(
      year: viewYear,
      month: viewMonth,
      confirmed: newValue,
    );

    if (newValue) {
      try {
        await repository.upsertMonthlySnapshot(
          year: viewYear,
          month: viewMonth,
        );

        setState(() {
          isConfirmed = true;
        });

        final next = DateTime(viewYear, viewMonth + 1);
        setState(() {
          viewYear = next.year;
          viewMonth = next.month;
        });

        _reloadComparisonFutures();

        await loadMonthlyLock();
        await loadAllMonthlyLocks();
        await fetchAssets();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not confirm month. Check your connection.'),
          ),
        );

        await repository.updateMonthlyLock(
          year: viewYear,
          month: viewMonth,
          confirmed: false,
        );

        if (!mounted) return;
        setState(() {
          isConfirmed = false;
        });
      }
      return;
    }

    setState(() {
      isConfirmed = false;
    });
  }

  Future<void> _onYearComparisonChanged(bool useYearOverYear) async {
    setState(() {
      isYearComparison = useYearOverYear;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isYearComparison', useYearOverYear);
  }

  void _toggleHideTotal() async {
    setState(() {
      hideTotal = !hideTotal;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideTotal', hideTotal);
  }

  Widget _buildAssetCard(
    Map<String, dynamic> a,
    Map<int, int> startByAssetId,
  ) {
    final aid = AssetHistoryMath.coerceInt(a['asset_id']) ??
        AssetHistoryMath.coerceInt(a['id']);
    final start = aid != null ? startByAssetId[aid] : null;

    return AssetCardWidget(
      asset: a,
      isConfirmed: isConfirmed,
      isCurrentMonth: isCurrentMonth,
      formatter: formatter,
      startOfYearValue: start,
      onEditCurrent: () async {
        final updated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                EditAssetPage(asset: Map<String, dynamic>.from(a)),
          ),
        );
        if (updated == true) {
          await fetchAssets();
        }
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
        if (updated == true) {
          await fetchAssets();
        }
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: false,
                floating: true,
                snap: true,
                centerTitle: true,
                title: Text(
                  'AssetNote',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'c1') {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CategorySettingsPage(),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'c1',
                        child: Text('Category settings'),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(
                    height: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: AssetsMonthSelectorStrip(
                  scrollController: monthScrollController,
                  viewYear: viewYear,
                  viewMonth: viewMonth,
                  isMonthConfirmed: isMonthConfirmed,
                  onMonthTap: (year, month) async {
                    setState(() {
                      viewYear = year;
                      viewMonth = month;
                    });
                    _reloadComparisonFutures();
                    await loadMonthlyLock();
                    await fetchAssets();
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: AssetsListBody(
                    startOfYearHistoryFuture: _startOfYearHistoryFuture,
                    previousMonthHistoryFuture: _previousMonthHistoryFuture,
                    sortedAssets: sortedAssets,
                    groupedDisplay: groupedDisplay,
                    isYearComparison: isYearComparison,
                    isCurrentMonth: isCurrentMonth,
                    hideTotal: hideTotal,
                    formatter: formatter,
                    cardController: cardController,
                    goalAmount: goalAmount,
                    userPercentile: userPercentile,
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
          Positioned(
            right: 20,
            bottom: 20,
            child: GestureDetector(
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => const AddAssetPage()),
                ).then((_) {
                  if (mounted) fetchAssets();
                });
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
