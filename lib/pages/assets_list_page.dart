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
  bool hideTotal = false;
  bool isConfirmed = false;
  bool isInitialLoading = true;

  // 表示モード: true=年初比, false=前月比
  bool isYearComparison = true;

  bool get isCurrentMonth {
    final now = DateTime.now();
    return viewYear == now.year && viewMonth == now.month;
  }

  List<Map<String, dynamic>> assets = [];
  final formatter = NumberFormat('#,###');

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
    repository = AssetsRepository(Supabase.instance.client);
    _initializePage(); // ← Supabase の初期化など
    _loadComparisonMode(); // ← 追加
    _loadHideTotal(); // ← SharedPreferences の読み込み
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

      if (isCurrentMonth) {
        final data = await repository.fetchCurrentAssets();
        if (!mounted) return;
        setState(() {
          assets = data;
        });
      } else {
        final data = await repository.fetchHistoryByDate(snapshotDate);
        if (!mounted) return;
        setState(() {
          assets = data;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        assets = [];
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

    final userId = Supabase.instance.client.auth.currentUser?.id;

    final bgParams = _getBackgroundColorFilterParams(context);
    final cardParams = _getCardColorFilterParams(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent, // ← 完全に透明に変更
                elevation: 0,
                pinned: false,
                floating: true,
                snap: true,
                centerTitle: false,
                title: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        'AssetNote',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                actions: [
                  // IconButton(
                  //   icon: const Icon(Icons.add),
                  //   onPressed: () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(builder: (_) => AddAssetPage()),
                  //     );
                  //   },
                  // ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'c1') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategorySettingsPage(),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'c1',
                        child: Text('Category settings'),
                      ),
                    ],
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

                        // 前月比モードの場合、前月のデータを使用
                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: previousMonthHistoryFuture,
                          builder: (context, previousSnapshot) {
                            final previousHistory =
                                previousSnapshot.data ??
                                const <Map<String, dynamic>>[];
                            final previousStartByAssetId =
                                _startValuesByAssetId(previousHistory);

                            // 使用するデータをモードに応じて切り替え
                            final actualHistory = isYearComparison
                                ? history
                                : previousHistory;
                            final actualStartByAssetId = isYearComparison
                                ? startByAssetId
                                : previousStartByAssetId;

                             final assetById = <int, Map<String, dynamic>>{};
                            // for (final asset in sortedAssets) {
                            //   final key =
                            //       _coerceInt(asset['asset_id']) ??
                            //       _coerceInt(asset['id']);
                            //   if (key != null) {
                            //     assetById[key] = asset;
                            //   }
                            // }

                            for (final asset in sortedAssets) {
                              // ★ assets_history には asset_id がある → 除外
                              if (asset.containsKey('asset_id')) continue;

                              final key = _coerceInt(asset['id']);
                              if (key != null) {
                                assetById[key] = asset;
                              }
                            }

                            // カテゴリごとの開始値合計を計算（モードに応じて切り替え）
                            final category1StartTotals = <String, int>{};

                            for (final h in actualHistory) {
                              final aid = _coerceInt(h['asset_id']);
                              if (aid == null) continue;

                              final asset = assetById[aid];
                              if (asset == null) continue;

                              final value = h['value'] as int? ?? 0;

                              // ★ 過去データ（history）優先 → なければ現在データ（assets）
                              final c1 =
                                  h['category1'] ?? // history のカテゴリ名
                                  asset['categories1']?['name'] ?? // assets のカテゴリ名
                                  '未分類';

                              category1StartTotals[c1] =
                                  (category1StartTotals[c1] ?? 0) + value;
                            }

                            return Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left),
                                      onPressed: () async {
                                        setState(() {
                                          final prev = DateTime(
                                            viewYear,
                                            viewMonth - 1,
                                          );
                                          viewYear = prev.year;
                                          viewMonth = prev.month;
                                        });
                                        await loadMonthlyLock();
                                        await fetchAssets();
                                      },
                                    ),
                                    Text(
                                      DateFormat(
                                        'MMMM yyyy',
                                        'en_US',
                                      ).format(DateTime(viewYear, viewMonth)),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed: () async {
                                        setState(() {
                                          final next = DateTime(
                                            viewYear,
                                            viewMonth + 1,
                                          );
                                          viewYear = next.year;
                                          viewMonth = next.month;
                                        });
                                        await loadMonthlyLock();
                                        await fetchAssets();
                                      },
                                    ),
                                  ],
                                ),
                                // モード切り替えボタンを追加
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: CupertinoSegmentedControl<bool>(
                                    groupValue: isYearComparison,
                                    children: const {
                                      true: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        child: Text('Year'),
                                      ),
                                      false: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        child: Text('Month'),
                                      ),
                                    },
                                    onValueChanged: (value) async {
                                      setState(() => isYearComparison = value);

                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setBool(
                                        'isYearComparison',
                                        isYearComparison,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  constraints: const BoxConstraints(
                                    minHeight: 165,
                                  ),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    24,
                                  ),

                                  // decoration: BoxDecoration(
                                  //   borderRadius: BorderRadius.circular(16),
                                  //   color: Theme.of(
                                  //     context,
                                  //   ).colorScheme.surface, // ← 画像があってもこの色が見える

                                  //   image: const DecorationImage(
                                  //     image: AssetImage('assets/bg/april.png'),
                                  //     fit: BoxFit.none, // ← 画像を拡大しない
                                  //     alignment:
                                  //         Alignment.topRight, // ← 右上にだけ配置
                                  //     scale: 5, // ← 必要なら調整（小さくする）
                                  //     // ← ColorFilter は完全に削除（影なし）
                                  //   ),
                                  // ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: () async {
                                          setState(() {
                                            hideTotal = !hideTotal;
                                          });

                                          final prefs =
                                              await SharedPreferences.getInstance();
                                          await prefs.setBool(
                                            'hideTotal',
                                            hideTotal,
                                          );
                                        },
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
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                      if (!isInitialLoading)
                                        _buildDiffText(
                                          currentTotal: total,
                                          startTotal: _sumHistoryValues(
                                            actualHistory,
                                          ),
                                          fontSize: 14,
                                        ),
                                      const SizedBox(height: 4),
                                      const SizedBox(height: 10),
                                      MonthlyConfirmToggle(
                                        isConfirmed: isConfirmed,
                                        onTap: handleConfirmToggle,
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
                                                  label: big.key,
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
                                        final midLabel = _secondCategoryTitle(
                                          mid.key,
                                        );
                                        return ExpansionTile(
                                          initiallyExpanded: true,
                                          tilePadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ),
                                          title: Padding(
                                            padding: const EdgeInsets.only(
                                              left: 12,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child:
                                                      categoryTitleWithOptionalFavicon(
                                                        label: midLabel,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500,
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
                                          ),
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
          ),
          // ★ 右下の追加ボタン（ここに入れる）
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
