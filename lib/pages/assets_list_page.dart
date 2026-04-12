import 'package:asset_note/pages/add_asset_page.dart';
import 'package:asset_note/pages/category_settings_page.dart';
import 'package:asset_note/pages/edit_asset_page.dart';
import 'package:asset_note/pages/edit_history_asset_page.dart';
import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/utils/category_favicon.dart';
import 'package:asset_note/viewmodels/assets_view_model.dart';
import 'package:asset_note/widgets/asset_card_widget.dart';
import 'package:asset_note/widgets/monthly_confirm_toggle.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';

class AssetsListPage extends StatefulWidget {
  const AssetsListPage({super.key});

  @override
  State<AssetsListPage> createState() => _AssetsListPageState();
}

class _AssetsListPageState extends State<AssetsListPage> {
  late final AssetsRepository repository;
  int viewYear = DateTime.now().year;
  int viewMonth = DateTime.now().month;
  int total = 0; // ★ これを追加（総資産）
  bool hideTotal = false;
  bool isConfirmed = false;
  bool isInitialLoading = true;
  List<Map<String, dynamic>>? actualHistory;
  int goalAmount = 0;
  late PageController cardController;

  bool isYearMode = false; // false = Month, true = Year
  final Map<String, List<int>> wealthDistribution = {
    "30s": [100, 300, 600, 1000, 1500, 2500],
  };
  String ageGroup = "30s";

  double calculatePercentile(int total, String ageGroup) {
    final dist = wealthDistribution[ageGroup]!;

    if (total < dist[0]) return 0.50; // 下位50%
    if (total < dist[1]) return 0.30; // 下位30%
    if (total < dist[2]) return 0.20; // 下位20%
    if (total < dist[3]) return 0.10; // 下位10%
    if (total < dist[4]) return 0.05; // 下位5%
    return 0.03; // 上位3%
  }

  double userPercentile = 0.20; // 初期値

  void updateUserPercentile() {
    setState(() {
      userPercentile = calculatePercentile(total, ageGroup);
    });
  }

  Map<String, bool> monthlyLock = {};
  Map<String, bool> saveMonthlyLock = {};

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

    // ★ 過去18ヶ月を開始点にする
    final start = DateTime(now.year, now.month - 18);

    // ★ 現在月が何番目の index か計算
    final index = (now.year - start.year) * 12 + (now.month - start.month);

    // ★ 1アイテムの幅（あなたの UI に合わせて調整）
    const itemWidth = 80.0;

    monthScrollController.jumpTo(index * itemWidth);
  }

  final ScrollController monthScrollController = ScrollController();

  // 表示モード: true=年初比, false=前月比
  bool isYearComparison = true;

  bool get isCurrentMonth {
    final now = DateTime.now();
    return viewYear == now.year && viewMonth == now.month;
  }

  List<Map<String, dynamic>> assets = [];
  final formatter = NumberFormat('#,###');

  Widget _buildMonthChip(int year, int month, {bool isCurrent = false}) {
    final date = DateTime(year, month);
    final label = DateFormat('yyyyMM').format(date);

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // ← これ超重要（タップ領域を確保）
      onTap: () async {
        setState(() {
          viewYear = date.year;
          viewMonth = date.month;
        });
        await loadMonthlyLock();
        await fetchAssets();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isCurrent
              ? (Theme.of(context).brightness == Brightness.light
                    ? Colors.white
                    : const Color(0xFF3A3A3C))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent
                ? (Theme.of(context).brightness == Brightness.light
                      ? Colors.black
                      : Colors.white)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  static int? _coerceInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  /// asset_id → Jan 1 snapshot value (one batch, no per-card API).
  static Map<int, int> _startValuesByAssetId(
    List<Map<String, dynamic>> history,
  ) {
    final m = <int, int>{};
    for (final h in history) {
      final aid = _coerceInt(h['asset_id']);
      if (aid == null) continue;
      m[aid] = _coerceInt(h['value']) ?? 0;
    }
    return m;
  }

  static String _secondCategoryTitle(String key) {
    if (key == '_' || key.isEmpty) return 'General';
    return key;
  }

  static int _startTotalForAssets(
    List<Map<String, dynamic>> items,
    Map<int, int> startByAssetId,
  ) {
    var t = 0;
    for (final a in items) {
      final aid = _coerceInt(a['asset_id']) ?? _coerceInt(a['id']);
      if (aid != null) t += startByAssetId[aid] ?? 0;
    }
    return t;
  }

  int _sumHistoryValues(List<Map<String, dynamic>> history) {
    var total = 0;
    for (final h in history) {
      total += h['value'] as int? ?? 0;
    }
    return total;
  }

  Widget _buildDiffText({
    required int currentTotal,
    required int startTotal,
    required double fontSize,
  }) {
    final diff = currentTotal - startTotal;
    final diffRate = startTotal > 0 ? (currentTotal / startTotal - 1) * 100 : 0;
    return Text(
      "${diff >= 0 ? '+' : ''}${formatter.format(diff)} "
      "(${diffRate.toStringAsFixed(1)}%)",
      style: TextStyle(
        fontSize: fontSize,
        color: diff >= 0 ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    viewYear = now.year;
    viewMonth = now.month;

    repository = AssetsRepository(Supabase.instance.client);
    cardController = PageController(viewportFraction: 0.92);

    _loadGoalAmount();
    _initializePage();
    _loadComparisonMode();
    _loadHideTotal();
    loadAllMonthlyLocks();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToCurrentMonth();
    });
  }

  //1枚目

  Widget _buildTotalAssetsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF1C1C1E),
        boxShadow: [
          if (Theme.of(context).brightness == Brightness.light)
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: GestureDetector(
              onTap: toggleHideTotal,
              child: isInitialLoading
                  ? const SizedBox(
                      height: 32,
                      width: 32,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(
                      hideTotal ? '¥••••••' : '¥${formatter.format(total)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 6),

          if (!isInitialLoading)
            Center(
              child: _buildDiffText(
                currentTotal: total,
                startTotal: _sumHistoryValues(actualHistory ?? []),
                fontSize: 14,
              ),
            ),

          const SizedBox(height: 20),

          if (goalAmount > 0) _buildGoalProgressBar(total, goalAmount),

          const SizedBox(height: 16),

          _buildPercentileLabel(userPercentile),

          const SizedBox(height: 20),

          Center(
            child: MonthlyConfirmToggle(
              isConfirmed: isConfirmed,
              onTap: handleConfirmToggle,
            ),
          ),
        ],
      ),
    );
  }

  //2枚目
  Widget _buildSecondCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.grey.withOpacity(0.2),
      ),
      child: const Center(child: Text("2枚目のカード（後で追加）")),
    );
  }

  Future<void> _loadGoalAmount() async {
    final prefs = await SharedPreferences.getInstance();
    //print("★★★★ goalAmount loaded = $goalAmount ★★★★");
    setState(() {
      goalAmount = prefs.getInt('goalAmount') ?? 30_000_000;
      //goalAmount = 30_000_000;
    });
    print(goalAmount);
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
    } catch (_) {
      // Still show assets if monthly lock fails to load.
    }

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

      // ★ 総資産を計算
      int sum = 0;
      for (final a in data) {
        final v = a['value'];
        if (v is int) sum += v;
        if (v is double) sum += v.toInt();
      }
      print("sum after calculation = $sum");

      setState(() {
        assets = data;
        total = sum; // ★ ここで総資産を更新
      });
      print("setState total = $total"); // ★ ここが重要

      // ★ 資産レベル（percentile）も更新
      updateUserPercentile();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        assets = [];
        total = 0; // ★ エラー時は0に戻す
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not load assets.')));
    }
  }

  Future<void> deleteAsset(int id) async {
    await repository.deleteCurrentAsset(id);
    fetchAssets();
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

        await loadMonthlyLock();
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

  // Widget _buildGoalProgressBar(int total, int goal) {
  //   print("GoalBar total = $total, goal = $goal");

  //   double progress = total / goal;

  //   if (progress.isNaN || progress.isInfinite) {
  //     progress = 0.0;
  //   }

  //   progress = progress.clamp(0.0, 1.0);

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         "目標額までの進捗",
  //         style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
  //       ),
  //       const SizedBox(height: 6),
  //       ClipRRect(
  //         borderRadius: BorderRadius.circular(8),
  //         child: LinearProgressIndicator(
  //           value: progress,
  //           minHeight: 10,
  //           backgroundColor: Colors.grey.shade300,
  //           valueColor: AlwaysStoppedAnimation<Color>(
  //             progress >= 1.0 ? Colors.green : Colors.blueAccent,
  //           ),
  //         ),
  //       ),
  //       const SizedBox(height: 4),
  //       Text(
  //         "${(progress * 100).toStringAsFixed(1)}%",
  //         style: const TextStyle(fontSize: 12),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildPeriodFilter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
      ),
      child: Row(
        children: [
          // Year
          GestureDetector(
            onTap: () async {
              setState(() => isYearComparison = true);

              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isYearComparison', isYearComparison);
            },
            child: Text(
              "Year",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isYearComparison
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            ),
          ),

          const SizedBox(width: 8),

          Text(
            "|",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),

          const SizedBox(width: 8),

          // Month
          GestureDetector(
            onTap: () async {
              setState(() => isYearComparison = false);

              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isYearComparison', isYearComparison);
            },
            child: Text(
              "Month",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: !isYearComparison
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgressBar(int total, int goal) {
    double progress = (total / goal).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "目標達成率 ${(progress * 100).toStringAsFixed(1)}%",
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF007AFF)),
          ),
        ),
      ],
    );
  } // Widget _buildWealthPyramid(double percentile) {
  //   // percentile = 0.0〜1.0（例：0.2 = 上位20%）

  //   List<String> levels = ["上位 5%", "上位10%", "上位20%", "上位30%", "上位50%"];

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         "資産レベル（同世代）",
  //         style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
  //       ),
  //       const SizedBox(height: 8),

  //       ...List.generate(levels.length, (i) {
  //         final levelPercent = [0.05, 0.10, 0.20, 0.30, 0.50][i];
  //         final isUser = percentile <= levelPercent;

  //         return Row(
  //           children: [
  //             Text(
  //               levels[i],
  //               style: TextStyle(
  //                 fontSize: 12,
  //                 color: isUser ? Colors.blueAccent : Colors.grey.shade500,
  //               ),
  //             ),
  //             const SizedBox(width: 8),
  //             Expanded(
  //               child: Row(
  //                 children: List.generate(i + 1, (j) {
  //                   return Padding(
  //                     padding: const EdgeInsets.symmetric(horizontal: 1),
  //                     child: Icon(
  //                       Icons.change_history, // ▲
  //                       size: 12,
  //                       color: isUser && j == i
  //                           ? Colors.blueAccent
  //                           : Colors.grey.shade400,
  //                     ),
  //                   );
  //                 }),
  //               ),
  //             ),
  //           ],
  //         );
  //       }),
  //     ],
  //   );
  // }

  void toggleHideTotal() async {
    setState(() {
      hideTotal = !hideTotal;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideTotal', hideTotal);
  }

  Widget _buildPercentileLabel(double percentile) {
    if (percentile <= 0) {
      return const Text(
        "資産レベル未計測",
        style: TextStyle(fontSize: 13, color: Colors.grey),
      );
    }

    final percent = (percentile * 100).toStringAsFixed(1);

    return Row(
      children: [
        Icon(Icons.trending_up, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Text(
          "あなたは日本の上位 $percent%",
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget assetCard(Map<String, dynamic> a, Map<int, int> startByAssetId) {
    final aid = _coerceInt(a['asset_id']) ?? _coerceInt(a['id']);
    final start = aid != null ? startByAssetId[aid] : null;

    return AssetCardWidget(
      asset: a,
      isConfirmed: isConfirmed,
      isCurrentMonth: isCurrentMonth,
      formatter: formatter,
      startOfYearValue: start,
      onEditCurrent: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EditAssetPage(asset: a)),
        );
        if (updated == true) {
          await fetchAssets();
        }
      },
      onEditHistory: () async {
        final updated = await Navigator.push(
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
        final id = _coerceInt(a['asset_id']) ?? _coerceInt(a['id']);
        if (id != null) deleteAsset(id);
      },
    );
  }

  /// Returns brightness-aware color and blend mode for background images
  Map<String, dynamic> _getBackgroundColorFilterParams(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return {
      'color': isDark
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.08),
      'blendMode': isDark ? BlendMode.lighten : BlendMode.darken,
    };
  }

  /// Returns brightness-aware color and blend mode for card images
  Map<String, dynamic> _getCardColorFilterParams(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return {
      'color': isDark
          ? Colors.white.withOpacity(0.25)
          : Colors.black.withOpacity(0.12),
      'blendMode': BlendMode.srcOver,
    };
  }

  @override
  Widget build(BuildContext context) {
    final sortedAssets = List<Map<String, dynamic>>.from(assets)
      ..sort((a, b) => (b['value'] ?? 0).compareTo(a['value'] ?? 0));

    final groupedDisplay = AssetsViewModel.groupForDisplay(sortedAssets);
    final total = AssetsViewModel.total(sortedAssets);
    final startOfYearHistoryFuture = repository.fetchStartOfYearHistory(
      year: viewYear,
    );

    final previousMonthHistoryFuture = repository.fetchPreviousMonthHistory(
      year: viewYear,
      month: viewMonth,
    );

    //final userId = Supabase.instance.client.auth.currentUser?.id;
    //final bgParams = _getBackgroundColorFilterParams(context);
    //final cardParams = _getCardColorFilterParams(context);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFF2F2F7) // ライト背景
          : const Color(0xFF000000), // ★ Appleダーク背景（黒）

      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ① AppBar
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: false,
                floating: true,
                snap: true,
                centerTitle: true,
                title: Text(
                  'AssetNote',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w600),
                ),
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'c1') {
                        Navigator.push(
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
                child: SizedBox(
                  height: 70, // ★ 40 → 100 に変更（2段構成にするため）
                  child: ListView.builder(
                    controller: monthScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: 36,
                    itemBuilder: (context, index) {
                      final now = DateTime.now();
                      final start = DateTime(now.year, now.month - 18);
                      final date = DateTime(start.year, start.month + index);

                      final label = DateFormat('yyyy/MM').format(date);

                      final isCurrent =
                          date.year == viewYear && date.month == viewMonth;

                      // ★ 月の状態を取得（confirmed / tentative）
                      final isConfirmed =
                          monthlyLock['${date.year}-${date.month.toString().padLeft(2, '0')}'] ==
                          true;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            setState(() {
                              viewYear = date.year;
                              viewMonth = date.month;
                            });
                            await loadMonthlyLock();
                            await fetchAssets();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? (Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.white
                                        : const Color(0xFF3A3A3C))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCurrent
                                    ? (Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.black
                                          : Colors.white)
                                    : Colors.grey.withOpacity(0.3),
                              ),
                            ),

                            // ★ ここを Column にしてボタンを入れる
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 年月
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                // ★ 総資産カードにあったボタンをそのまま配置
                                Text(
                                  isMonthConfirmed(date.year, date.month)
                                      ? '確定済み'
                                      : '未確定',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        isMonthConfirmed(date.year, date.month)
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ), // ③ 残りのコンテンツ（元の SliverPadding + SliverList + FutureBuilder 部分）
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: startOfYearHistoryFuture,
                      builder: (context, snapshot) {
                        final history =
                            snapshot.data ?? const <Map<String, dynamic>>[];

                        final startByAssetId = _startValuesByAssetId(history);

                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: previousMonthHistoryFuture,
                          builder: (context, previousSnapshot) {
                            final previousHistory =
                                previousSnapshot.data ??
                                const <Map<String, dynamic>>[];
                            final previousStartByAssetId =
                                _startValuesByAssetId(previousHistory);

                            final actualHistory = isYearComparison
                                ? history
                                : previousHistory;
                            final actualStartByAssetId = isYearComparison
                                ? startByAssetId
                                : previousStartByAssetId;

                            final assetById = <int, Map<String, dynamic>>{};
                            for (final asset in sortedAssets) {
                              final key =
                                  _coerceInt(asset['asset_id']) ??
                                  _coerceInt(asset['id']);
                              if (key != null) {
                                assetById[key] = asset;
                              }
                            }

                            final category1StartTotals = <String, int>{};
                            for (final h in actualHistory) {
                              final aid = _coerceInt(h['asset_id']);
                              if (aid == null) continue;

                              final asset = assetById[aid];
                              if (asset == null) continue;

                              final value = h['value'] as int? ?? 0;

                              final c1Id =
                                  h['category1_id'] ?? asset['category1_id'];
                              if (c1Id == null) continue;

                              category1StartTotals[c1Id] =
                                  (category1StartTotals[c1Id] ?? 0) + value;
                            }

                            final category1EndTotals = <String, int>{};
                            for (final a in sortedAssets) {
                              final c1Id = a['category1_id'];
                              if (c1Id == null) continue;

                              final value = a['value'] as int? ?? 0;
                              category1EndTotals[c1Id] =
                                  (category1EndTotals[c1Id] ?? 0) + value;
                            }

                            final category1DiffTotals = <String, int>{};
                            for (final c1Id in category1EndTotals.keys) {
                              final start = category1StartTotals[c1Id] ?? 0;
                              final end = category1EndTotals[c1Id] ?? 0;
                              category1DiffTotals[c1Id] = end - start;
                            }

                            String resolveCategory1Name(String c1Id) {
                              // ★ 現在月（assets のカテゴリ名）
                              if (isCurrentMonth) {
                                for (final a in sortedAssets) {
                                  if (a['category1_id'] == c1Id) {
                                    return a['categories1']?['name'] ?? '未分類';
                                  }
                                }
                                return '未分類';
                              }

                              // ★ 過去月（history のスナップショット名）
                              for (final h in actualHistory) {
                                if (h['category1_id'] == c1Id) {
                                  return h['category1'] ?? '未分類'; // ← ここ重要
                                }
                              }

                              return '未分類';
                            }

                            String resolveCategory2Name(String c2Id) {
                              // ★ 現在月（assets のカテゴリ名）
                              if (isCurrentMonth) {
                                for (final a in sortedAssets) {
                                  if (a['category2_id'] == c2Id) {
                                    return a['categories2']?['name'] ?? '未分類';
                                  }
                                }
                                return '未分類';
                              }

                              // ★ 過去月（history のスナップショット名）
                              for (final h in actualHistory) {
                                if (h['category2_id'] == c2Id) {
                                  return h['category2'] ?? '未分類'; // ← ここ重要
                                }
                              }

                              return '未分類';
                            }

                            // ★ ここで “普通の Widget” を返す（CustomScrollView は返さない）
                            return Column(
                              children: [
                                // Row(
                                //   mainAxisAlignment: MainAxisAlignment.center,
                                //   children: [
                                //     IconButton(
                                //       icon: const Icon(Icons.chevron_left),
                                //       onPressed: () async {
                                //         setState(() {
                                //           final prev = DateTime(
                                //             viewYear,
                                //             viewMonth - 1,
                                //           );
                                //           viewYear = prev.year;
                                //           viewMonth = prev.month;
                                //         });
                                //         await loadMonthlyLock();
                                //         await fetchAssets();
                                //       },
                                //     ),
                                //     Text(
                                //       DateFormat(
                                //         'MMMM yyyy',
                                //         'en_US',
                                //       ).format(DateTime(viewYear, viewMonth)),
                                //       style: const TextStyle(
                                //         fontSize: 16,
                                //         fontWeight: FontWeight.bold,
                                //       ),
                                //     ),
                                //     IconButton(
                                //       icon: const Icon(Icons.chevron_right),
                                //       onPressed: () async {
                                //         setState(() {
                                //           final next = DateTime(
                                //             viewYear,
                                //             viewMonth + 1,
                                //           );
                                //           viewYear = next.year;
                                //           viewMonth = next.month;
                                //         });
                                //         await loadMonthlyLock();
                                //         await fetchAssets();
                                //       },
                                //     ),
                                //   ],
                                // ),

                                // ★ 総資産カード
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 190, // カードの高さに合わせる
                                  child: PageView(
                                    controller:
                                        cardController, // ← initState で作る
                                    children: [
                                      // ★ 1枚目：今の総資産カード
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.fromLTRB(
                                          20,
                                          20,
                                          20,
                                          24,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.light
                                              ? Colors.white
                                              : const Color(0xFF1C1C1E),
                                          boxShadow: [
                                            if (Theme.of(context).brightness ==
                                                Brightness.light)
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.06,
                                                ),
                                                blurRadius: 16,
                                                offset: const Offset(0, 6),
                                              ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center, // ★ 縦中央
                                          children: [
                                            // ★ 左上：トグル
                                            MonthlyConfirmToggle(
                                              isConfirmed: isConfirmed,
                                              onTap: handleConfirmToggle,
                                              size: 20,
                                            ),

                                            const SizedBox(height: 12),

                                            // ★ カード中央：総資産
                                            Center(
                                              child: GestureDetector(
                                                onTap: toggleHideTotal,
                                                child: isInitialLoading
                                                    ? const SizedBox(
                                                        height: 32,
                                                        width: 32,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2.5,
                                                            ),
                                                      )
                                                    : Text(
                                                        hideTotal
                                                            ? '¥••••••'
                                                            : '¥${formatter.format(total)}',
                                                        style: const TextStyle(
                                                          fontSize: 32,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                              ),
                                            ),

                                            const SizedBox(height: 10),

                                            // ★ 期間フィルター + 収益（横並び）
                                            if (!isInitialLoading)
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  // ← 控えめ Year / Month（ロジックは isYearComparison のまま）
                                                  Row(
                                                    children: [
                                                      GestureDetector(
                                                        onTap: () async {
                                                          setState(
                                                            () =>
                                                                isYearComparison =
                                                                    true,
                                                          );
                                                          final prefs =
                                                              await SharedPreferences.getInstance();
                                                          await prefs.setBool(
                                                            'isYearComparison',
                                                            isYearComparison,
                                                          );
                                                        },
                                                        child: Text(
                                                          "Year",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color:
                                                                isYearComparison
                                                                ? Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary
                                                                : Colors.grey,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        "/",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey
                                                              .shade500,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      GestureDetector(
                                                        onTap: () async {
                                                          setState(
                                                            () =>
                                                                isYearComparison =
                                                                    false,
                                                          );
                                                          final prefs =
                                                              await SharedPreferences.getInstance();
                                                          await prefs.setBool(
                                                            'isYearComparison',
                                                            isYearComparison,
                                                          );
                                                        },
                                                        child: Text(
                                                          "Month",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color:
                                                                !isYearComparison
                                                                ? Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary
                                                                : Colors.grey,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  const SizedBox(width: 12),

                                                  // → 右側：収益
                                                  _buildDiffText(
                                                    currentTotal: total,
                                                    startTotal:
                                                        _sumHistoryValues(
                                                          actualHistory ?? [],
                                                        ),
                                                    fontSize: 14,
                                                  ),
                                                ],
                                              ),

                                            const SizedBox(height: 20),
                                          ],

                                          // Padding(
                                          //   padding: const EdgeInsets.only(top: 8),
                                          //   child: CupertinoSegmentedControl<bool>(
                                          //     groupValue: isYearComparison,
                                          //     children: const {
                                          //       true: Padding(
                                          //         padding: EdgeInsets.symmetric(
                                          //           horizontal: 12,
                                          //           vertical: 6,
                                          //         ),
                                          //         child: Text('Year'),
                                          //       ),
                                          //       false: Padding(
                                          //         padding: EdgeInsets.symmetric(
                                          //           horizontal: 12,
                                          //           vertical: 6,
                                          //         ),
                                          //         child: Text('Month'),
                                          //       ),
                                          //     },
                                          //     onValueChanged: (value) async {
                                          //       setState(() => isYearComparison = value);

                                          //       final prefs =
                                          //           await SharedPreferences.getInstance();
                                          //       await prefs.setBool(
                                          //         'isYearComparison',
                                          //         isYearComparison,
                                          //       );
                                          //     },
                                          //   ),
                                          // ),
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        padding: const EdgeInsets.fromLTRB(
                                          20,
                                          20,
                                          20,
                                          24,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.light
                                              ? Colors.white
                                              : const Color(0xFF1C1C1E),
                                          boxShadow: [
                                            if (Theme.of(context).brightness ==
                                                Brightness.light)
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.06,
                                                ),
                                                blurRadius: 16,
                                                offset: const Offset(0, 6),
                                              ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // ③ 目標進捗バー
                                            if (goalAmount > 0)
                                              _buildGoalProgressBar(
                                                total,
                                                goalAmount,
                                              ),

                                            const SizedBox(height: 20),

                                            // ④ 上位◯％
                                            _buildPercentileLabel(
                                              userPercentile,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                ...groupedDisplay.entries.map((big) {
                                  final bigTotal =
                                      AssetsViewModel.categoryTotal(big.value);
                                  return ExpansionTile(
                                    initiallyExpanded: true,
                                    tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    title: GestureDetector(
                                      onTap: null,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child:
                                                categoryTitleWithOptionalFavicon(
                                                  label: resolveCategory1Name(
                                                    big.key,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '¥${formatter.format(bigTotal)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              _buildDiffText(
                                                currentTotal: bigTotal,
                                                startTotal:
                                                    category1StartTotals[big
                                                        .key] ??
                                                    0,
                                                fontSize: 12,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    children: [
                                      ...big.value.entries.map((mid) {
                                        final midTotal =
                                            AssetsViewModel.secondCategoryTotal(
                                              mid.value,
                                            );

                                        // ★ ここが最重要：ID → 名前に変換
                                        final midLabel = resolveCategory2Name(
                                          mid.key,
                                        );

                                        return ExpansionTile(
                                          initiallyExpanded: true,
                                          tilePadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ),
                                          title: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  midLabel, // ★ 名前を表示
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '¥${formatter.format(midTotal)}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                  _buildDiffText(
                                                    currentTotal: midTotal,
                                                    startTotal:
                                                        _startTotalForAssets(
                                                          mid.value,
                                                          actualStartByAssetId,
                                                        ),
                                                    fontSize: 11,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),

                                          // ★ 小分類（資産カード）を展開
                                          children: [
                                            GridView.count(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              crossAxisCount: 3,
                                              crossAxisSpacing: 10,
                                              mainAxisSpacing: 10,
                                              childAspectRatio: 1.25,
                                              padding: const EdgeInsets.only(
                                                top: 5,
                                                bottom: 5,
                                              ),
                                              children: mid.value
                                                  .map<Widget>(
                                                    (a) => assetCard(
                                                      a,
                                                      actualStartByAssetId,
                                                    ),
                                                  )
                                                  .toList(),
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
                      },
                    ),
                  ]),
                ),
              ),
            ],
          ), // ★ 右下の追加ボタン（ここに入れる）
          Positioned(
            right: 20,
            bottom: 20,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddAssetPage()),
                );
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue,
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
