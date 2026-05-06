import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/widgets/asset_timeline_widget.dart';
import 'package:asset_note/widgets/assets_month_selector_strip.dart';
import 'package:asset_note/widgets/monthly_attribution_summary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _fmt = NumberFormat('#,###', 'ja_JP');

typedef _AssetInGroup = ({
  int assetId,
  String name,
  int diff,
  int? attributedAmount,
  bool isIncomeEntry,
  int realAssetId,
  bool isEntryExcluded,
});

typedef _LabelGroup = ({
  String label,
  int totalAmount,
  bool isUnexplained,
  bool isExcluded,
  List<_AssetInGroup> assets,
});

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  late final AssetsRepository _repository;

  int viewYear = DateTime.now().year;
  int viewMonth = DateTime.now().month;

  List<Map<String, dynamic>> _assets = [];
  int _totalChange = 0;
  bool _isLoading = true;

  Map<String, bool> _monthlyLock = {};
  Map<int, List<MonthlyLabelEntry>> _labelEntries = {};
  Set<int> _excludedSet = {};

  final ScrollController _monthScrollController = ScrollController();

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return viewYear == now.year && viewMonth == now.month;
  }

  DateTime get _stripEnd {
    final now = DateTime.now();
    DateTime? latest;
    for (final entry in _monthlyLock.entries) {
      if (!entry.value) continue;
      final parts = entry.key.split('-');
      final d = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      if (latest == null || d.isAfter(latest)) latest = d;
    }
    if (latest == null) return now;
    final nextAfterConfirmed = DateTime(latest.year, latest.month + 1);
    return nextAfterConfirmed.isAfter(now) ? nextAfterConfirmed : now;
  }

  bool _isMonthConfirmed(int year, int month) {
    return _monthlyLock['$year-${month.toString().padLeft(2, '0')}'] ?? false;
  }

  @override
  void initState() {
    super.initState();
    _repository = AssetsRepository(Supabase.instance.client);
    _loadAllMonthlyLocks();
    _fetchData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrentMonth());
  }

  @override
  void dispose() {
    _monthScrollController.dispose();
    super.dispose();
  }

  void _jumpToCurrentMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 18);
    final index = (now.year - start.year) * 12 + (now.month - start.month);
    _monthScrollController.jumpTo(index * 80.0);
  }

  Future<void> _loadAllMonthlyLocks() async {
    final rows = await _repository.fetchAllMonthlyLocks();
    final map = <String, bool>{};
    for (final row in rows) {
      final y = row['year'] as int;
      final m = row['month'] as int;
      final key = '$y-${m.toString().padLeft(2, '0')}';
      map[key] = row['confirmed'] as bool;
    }
    if (!mounted) return;
    setState(() => _monthlyLock = map);
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final snapshotDate =
          '$viewYear-${viewMonth.toString().padLeft(2, '0')}-01';

      final List<Map<String, dynamic>> rawAssets = _isCurrentMonth
          ? await _repository.fetchCurrentAssets()
          : await _repository.fetchHistoryByDate(snapshotDate);

      final prevHistory = await _repository.fetchPreviousMonthHistory(
        year: viewYear,
        month: viewMonth,
      );

      final prevMap = <int, int>{};
      for (final a in prevHistory) {
        final id = (a['asset_id'] as num).toInt();
        prevMap[id] = (a['value'] as num).toInt();
      }

      final normalized = rawAssets.map((a) {
        final assetId = _isCurrentMonth
            ? (a['id'] is int ? a['id'] as int : (a['id'] as num).toInt())
            : (a['asset_id'] is int
                ? a['asset_id'] as int
                : (a['asset_id'] as num).toInt());
        final value = (a['value'] as num).toInt();
        final prevValue = prevMap[assetId];
        final diff = value - (prevValue ?? 0);
        String? cat1;
        String? cat2;
        if (_isCurrentMonth) {
          final c1 = a['categories1'] as Map<String, dynamic>?;
          cat1 = c1?['name'] as String?;
          final c2 = a['categories2'] as Map<String, dynamic>?;
          cat2 = c2?['name'] as String?;
        } else {
          cat1 = a['category1_name'] as String?;
          cat2 = a['category2_name'] as String?;
        }
        return {
          ...a,
          '_asset_id': assetId,
          '_value': value,
          '_prev_value': prevValue,
          '_diff': diff,
          '_cat1': cat1,
          '_cat2': cat2,
        };
      }).toList();

      normalized.sort((a, b) {
        final da = (a['_diff'] as int?)?.abs() ?? 0;
        final db = (b['_diff'] as int?)?.abs() ?? 0;
        return db.compareTo(da);
      });

      final (labels, excluded) = await _repository.fetchMonthlyMeta(
        year: viewYear,
        month: viewMonth,
      );

      final incomeMemos = await _repository.fetchIncomeMemosForMonth(
        year: viewYear,
        month: viewMonth,
      );
      for (final m in incomeMemos) {
        final memoId = (m['id'] as num).toInt();
        final amount = (m['amount'] as num?)?.toInt() ?? 0;
        final dir = m['direction'] as String?;
        final signedAmount = dir == '出' ? -amount : amount;
        if (signedAmount == 0) continue;
        normalized.add({
          '_asset_id': -memoId,
          '_value': 0,
          '_prev_value': null,
          '_diff': signedAmount,
          '_cat1': null,
          '_cat2': null,
          'name': m['memo'] as String? ?? '収益',
          '_is_income_entry': true,
          'asset_id': (m['asset_id'] as num).toInt(),
        });
      }

      int totalChange = 0;
      for (final a in normalized) {
        final id = a['_asset_id'] as int;
        if (a['_is_income_entry'] == true) continue;
        final diff = a['_diff'] as int?;
        if (diff == null) continue;
        final assetEntries = labels[id] ?? <MonthlyLabelEntry>[];
        if (assetEntries.isEmpty) {
          // ラベルなし: 資産全体の除外フラグ
          if (!excluded.contains(id)) totalChange += diff;
        } else {
          // ラベルあり: 除外エントリーの帰属額を差し引く
          int contribution = diff;
          for (final entry in assetEntries) {
            if (entry.excluded) contribution -= (entry.amount ?? diff);
          }
          totalChange += contribution;
        }
      }

      if (!mounted) return;
      setState(() {
        _assets = normalized;
        _totalChange = totalChange;
        _labelEntries = labels;
        _excludedSet = excluded;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _recomputeTotalChange() {
    int total = 0;
    for (final a in _assets) {
      final id = a['_asset_id'] as int;
      if (a['_is_income_entry'] == true) continue;
      final diff = a['_diff'] as int?;
      if (diff == null) continue;
      final entries = _labelEntries[id] ?? <MonthlyLabelEntry>[];
      if (entries.isEmpty) {
        if (!_excludedSet.contains(id)) total += diff;
      } else {
        int contribution = diff;
        for (final entry in entries) {
          if (entry.excluded) contribution -= (entry.amount ?? diff);
        }
        total += contribution;
      }
    }
    _totalChange = total;
  }

  void _showAssetDetail(int assetId, String assetName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            assetName,
                            style: Theme.of(ctx)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    AssetTimeline(assetId: assetId, assetName: assetName),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLabelEditor(int assetId, String assetName, int? diff) {
    final initialEntries =
        List<MonthlyLabelEntry>.from(_labelEntries[assetId] ?? []);
    var isExcluded = _excludedSet.contains(assetId);

    final labelCtrls = <TextEditingController>[];
    final amountCtrls = <TextEditingController>[];
    final excludedList = <bool>[];

    if (initialEntries.isEmpty) {
      labelCtrls.add(TextEditingController());
      amountCtrls.add(TextEditingController());
      excludedList.add(false);
    } else {
      for (final e in initialEntries) {
        labelCtrls.add(TextEditingController(text: e.label));
        amountCtrls.add(TextEditingController(
          text: e.amount != null ? e.amount.toString() : '',
        ));
        excludedList.add(e.excluded);
      }
    }

    const suggestions = ['株の収益', '配当金', '新規取得', '積み立て', '売却益', '為替差益', '入金'];

    int calcRemainder() {
      if (diff == null) return 0;
      int total = 0;
      for (final c in amountCtrls) {
        final v = int.tryParse(c.text.replaceAll(RegExp(r'[^\d]'), ''));
        if (v != null) total += v;
      }
      return diff - total;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final cs = Theme.of(ctx).colorScheme;
          final diffIsUp = diff != null && diff >= 0;
          final remainder = calcRemainder();
          final hasMultiple = labelCtrls.length > 1;
          final anyAmountEntered = amountCtrls.any((c) => c.text.isNotEmpty);
          final anyValidLabel = labelCtrls.any((c) => c.text.trim().isNotEmpty);
          final canAdd = labelCtrls.length < 5 && diff != null;
          final showPerEntryExclude = anyValidLabel;

          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        assetName,
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (diff != null) ...[
                      Icon(
                          diffIsUp
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 14,
                          color: diffIsUp ? Colors.green : Colors.red),
                      const SizedBox(width: 2),
                      Text('¥${_fmt.format(diff.abs())}',
                          style:
                              Theme.of(ctx).textTheme.labelMedium?.copyWith(
                                    color: diffIsUp
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.w600,
                                  )),
                    ] else
                      Text('前月なし',
                          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                                color:
                                    cs.onSurface.withValues(alpha: 0.4),
                              )),
                  ],
                ),
                const SizedBox(height: 4),
                Text('この月の変動に内訳ラベルを付けます',
                    style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        )),
                const SizedBox(height: 16),

                ...List.generate(labelCtrls.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasMultiple)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Text('ラベル ${i + 1}',
                                    style: Theme.of(ctx)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: cs.onSurface
                                              .withValues(alpha: 0.5),
                                          fontWeight: FontWeight.w600,
                                        )),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    labelCtrls[i].dispose();
                                    amountCtrls[i].dispose();
                                    setModalState(() {
                                      labelCtrls.removeAt(i);
                                      amountCtrls.removeAt(i);
                                      excludedList.removeAt(i);
                                    });
                                  },
                                  child: Icon(Icons.close,
                                      size: 16,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.4)),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: labelCtrls[i],
                                autofocus: i == 0 && initialEntries.isEmpty,
                                maxLength: 50,
                                decoration: InputDecoration(
                                  hintText: '理由を入力',
                                  counterText: '',
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                ),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: amountCtrls[i],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: diff != null ? '全額' : '任意',
                                  prefixText: '¥',
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 10),
                                ),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                          ],
                        ),
                        // エントリーごとの除外トグル
                        if (showPerEntryExclude) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.remove_circle_outline,
                                  size: 13,
                                  color: excludedList[i]
                                      ? cs.onSurface.withValues(alpha: 0.55)
                                      : cs.onSurface.withValues(alpha: 0.3)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '収益から除外',
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: excludedList[i]
                                            ? cs.onSurface
                                                .withValues(alpha: 0.7)
                                            : cs.onSurface
                                                .withValues(alpha: 0.4),
                                      ),
                                ),
                              ),
                              Transform.scale(
                                scale: 0.75,
                                alignment: Alignment.centerRight,
                                child: Switch(
                                  value: excludedList[i],
                                  onChanged: (v) => setModalState(
                                      () => excludedList[i] = v),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: suggestions
                      .map((s) => ActionChip(
                            label:
                                Text(s, style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              final target = labelCtrls
                                  .indexWhere((c) => c.text.isEmpty);
                              final idx = target >= 0
                                  ? target
                                  : labelCtrls.length - 1;
                              if (idx >= 0) {
                                labelCtrls[idx].text = s;
                                setModalState(() {});
                              }
                            },
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),

                if (diff != null && anyAmountEntered) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (remainder == 0 ? Colors.green : Colors.orange)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          remainder == 0
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          size: 14,
                          color: remainder == 0
                              ? Colors.green.shade600
                              : Colors.orange.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          remainder == 0
                              ? '全額を内訳に割り当て済み'
                              : '残り: ${remainder >= 0 ? "+" : ""}¥${_fmt.format(remainder)}',
                          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                                color: remainder == 0
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                if (canAdd) ...[
                  TextButton.icon(
                    onPressed: () {
                      final rem = anyAmountEntered ? remainder : null;
                      setModalState(() {
                        labelCtrls.add(TextEditingController());
                        amountCtrls.add(TextEditingController(
                          text: (rem != null && rem != 0)
                              ? rem.abs().toString()
                              : '',
                        ));
                        excludedList.add(false);
                      });
                    },
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('ラベルを追加'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: cs.primary,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // ラベルなし時のみ資産全体の除外スイッチを表示
                if (!showPerEntryExclude) ...[
                  Container(
                    decoration: BoxDecoration(
                      color:
                          cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('収益に含めない',
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.w500)),
                              Text('前月値の誤りなど、計算から除外します',
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: cs.onSurface
                                            .withValues(alpha: 0.45),
                                      )),
                            ],
                          ),
                        ),
                        Switch(
                          value: isExcluded,
                          onChanged: (v) async {
                            setModalState(() => isExcluded = v);
                            try {
                              await _repository.setMonthlyExclusion(
                                assetId: assetId,
                                year: viewYear,
                                month: viewMonth,
                                excluded: v,
                              );
                              if (!mounted) return;
                              setState(() {
                                if (v) {
                                  _excludedSet.add(assetId);
                                } else {
                                  _excludedSet.remove(assetId);
                                }
                                _recomputeTotalChange();
                              });
                            } catch (_) {
                              setModalState(() => isExcluded = !v);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('除外設定の保存に失敗しました')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else
                  const SizedBox(height: 16),

                Row(
                  children: [
                    if (initialEntries.isNotEmpty) ...[
                      OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await _repository.deleteMonthlyLabel(
                              assetId: assetId,
                              year: viewYear,
                              month: viewMonth,
                            );
                            if (!mounted) return;
                            setState(
                                () => _labelEntries.remove(assetId));
                          } catch (_) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('ラベルの削除に失敗しました')),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('削除'),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: anyValidLabel
                            ? () async {
                                final validLabels = <String>[];
                                final validAmounts = <int?>[];
                                final validExcluded = <bool>[];
                                for (int i = 0;
                                    i < labelCtrls.length;
                                    i++) {
                                  final label =
                                      labelCtrls[i].text.trim();
                                  if (label.isEmpty) continue;
                                  final amtStr = amountCtrls[i]
                                      .text
                                      .replaceAll(
                                          RegExp(r'[^\d]'), '');
                                  validLabels.add(label);
                                  validAmounts.add(
                                      amtStr.isNotEmpty
                                          ? int.tryParse(amtStr)
                                          : null);
                                  validExcluded.add(
                                      i < excludedList.length
                                          ? excludedList[i]
                                          : false);
                                }
                                Navigator.pop(ctx);
                                try {
                                  final newEntries =
                                      <MonthlyLabelEntry>[
                                    for (int i = 0;
                                        i < validLabels.length;
                                        i++)
                                      MonthlyLabelEntry(
                                        label: validLabels[i],
                                        amount: validAmounts[i],
                                        entryIndex: i,
                                        excluded: validExcluded[i],
                                      ),
                                  ];
                                  await _repository.replaceMonthlyLabels(
                                    assetId: assetId,
                                    year: viewYear,
                                    month: viewMonth,
                                    entries: newEntries,
                                  );
                                  if (!mounted) return;
                                  setState(() {
                                    _labelEntries[assetId] = newEntries;
                                    // ラベルを持つようになった資産は
                                    // 資産全体除外から外す
                                    _excludedSet.remove(assetId);
                                    _recomputeTotalChange();
                                  });
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'ラベルの保存に失敗しました: $e')),
                                  );
                                }
                              }
                            : null,
                        style: FilledButton.styleFrom(
                            shape: const StadiumBorder()),
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_LabelGroup> _buildLabelGroups() {
    final unexplainedAssets = <_AssetInGroup>[];
    final excludedAssets = <_AssetInGroup>[];
    final labelMap =
        <String, ({int total, List<_AssetInGroup> assets})>{};

    for (final a in _assets) {
      final assetId = a['_asset_id'] as int;
      final diff = a['_diff'] as int?;
      if (diff == null || diff == 0) continue;

      final name = a['name'] as String? ?? '不明';
      final isIncomeEntry = a['_is_income_entry'] == true;
      final realAssetId =
          isIncomeEntry ? (a['asset_id'] as int) : assetId;

      // ラベルなし・資産全体除外
      if (_excludedSet.contains(assetId)) {
        excludedAssets.add((
          assetId: assetId,
          name: name,
          diff: diff,
          attributedAmount: null,
          isIncomeEntry: isIncomeEntry,
          realAssetId: realAssetId,
          isEntryExcluded: true,
        ));
        continue;
      }

      final entries = _labelEntries[assetId];
      if (entries == null || entries.isEmpty) {
        unexplainedAssets.add((
          assetId: assetId,
          name: name,
          diff: diff,
          attributedAmount: null,
          isIncomeEntry: isIncomeEntry,
          realAssetId: realAssetId,
          isEntryExcluded: false,
        ));
        continue;
      }

      // ラベルありでも全エントリー除外なら除外グループへ
      final allExcluded = entries.every((e) => e.excluded);
      if (allExcluded) {
        excludedAssets.add((
          assetId: assetId,
          name: name,
          diff: diff,
          attributedAmount: null,
          isIncomeEntry: isIncomeEntry,
          realAssetId: realAssetId,
          isEntryExcluded: true,
        ));
        continue;
      }

      // エントリーをラベルグループへ振り分け
      for (final entry in entries) {
        final attributed = entry.amount ?? diff;
        final item = (
          assetId: assetId,
          name: name,
          diff: diff,
          attributedAmount: entry.amount,
          isIncomeEntry: isIncomeEntry,
          realAssetId: realAssetId,
          isEntryExcluded: entry.excluded,
        );
        final existing = labelMap[entry.label];
        // グループ合計は除外分を含めない
        final addToTotal = entry.excluded ? 0 : attributed;
        if (existing == null) {
          labelMap[entry.label] = (total: addToTotal, assets: [item]);
        } else {
          labelMap[entry.label] = (
            total: existing.total + addToTotal,
            assets: [...existing.assets, item],
          );
        }
      }
    }

    final result = <_LabelGroup>[];

    if (unexplainedAssets.isNotEmpty) {
      unexplainedAssets
          .sort((a, b) => b.diff.abs().compareTo(a.diff.abs()));
      result.add((
        label: '未説明',
        totalAmount:
            unexplainedAssets.fold(0, (s, a) => s + a.diff),
        isUnexplained: true,
        isExcluded: false,
        assets: unexplainedAssets,
      ));
    }

    final labelGroups = labelMap.entries.map((e) {
      final sorted = [...e.value.assets]
        ..sort((a, b) => (b.attributedAmount ?? b.diff)
            .abs()
            .compareTo((a.attributedAmount ?? a.diff).abs()));
      return (
        label: e.key,
        totalAmount: e.value.total,
        isUnexplained: false,
        isExcluded: false,
        assets: sorted,
      );
    }).toList()
      ..sort(
          (a, b) => b.totalAmount.abs().compareTo(a.totalAmount.abs()));
    result.addAll(labelGroups);

    if (excludedAssets.isNotEmpty) {
      excludedAssets
          .sort((a, b) => b.diff.abs().compareTo(a.diff.abs()));
      result.add((
        label: '除外',
        totalAmount: excludedAssets.fold(0, (s, a) => s + a.diff),
        isUnexplained: false,
        isExcluded: true,
        assets: excludedAssets,
      ));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUp = _totalChange >= 0;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFF000000),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: false,
            floating: true,
            snap: true,
            centerTitle: false,
            title: Text(
              '分析',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge!
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AssetsMonthSelectorStrip(
                scrollController: _monthScrollController,
                viewYear: viewYear,
                viewMonth: viewMonth,
                isMonthConfirmed: _isMonthConfirmed,
                onMonthTap: (year, month) async {
                  setState(() {
                    viewYear = year;
                    viewMonth = month;
                  });
                  await _fetchData();
                },
                onConfirmTap: () {},
                isConfirmed: false,
                stripEnd: _stripEnd,
                showConfirmButton: false,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
            sliver: SliverToBoxAdapter(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 月サマリーカード
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.outline
                                  .withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$viewYear年$viewMonth月 収益額',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    isUp
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 20,
                                    color:
                                        isUp ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '¥${_fmt.format(_totalChange.abs())}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isUp
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                  ),
                                ],
                              ),
                              if (_assets.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${_assets.length}資産',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // 内訳サマリー（常時表示）
                        if (_assets.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          MonthlyAttributionSummary(
                            totalChange: _totalChange,
                            assets: _assets,
                            labelEntries: _labelEntries,
                            excludedSet: _excludedSet,
                            viewYear: viewYear,
                            viewMonth: viewMonth,
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ラベルグループリスト
                        if (_assets.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 40),
                              child: Text(
                                'この月のデータがありません',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.4),
                                    ),
                              ),
                            ),
                          )
                        else
                          ..._buildLabelGroups().map((g) => Padding(
                                key: ValueKey(g.label),
                                padding:
                                    const EdgeInsets.only(bottom: 10),
                                child: _LabelGroupTile(
                                  group: g,
                                  labelEntries: _labelEntries,
                                  excludedSet: _excludedSet,
                                  onLabelEdit: (id, name, diff) =>
                                      _showLabelEditor(id, name, diff),
                                  onAssetDetail: (id, name) =>
                                      _showAssetDetail(id, name),
                                ),
                              )),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelGroupTile extends StatefulWidget {
  const _LabelGroupTile({
    required this.group,
    required this.labelEntries,
    required this.excludedSet,
    required this.onLabelEdit,
    required this.onAssetDetail,
  });

  final _LabelGroup group;
  final Map<int, List<MonthlyLabelEntry>> labelEntries;
  final Set<int> excludedSet;
  final void Function(int assetId, String name, int? diff) onLabelEdit;
  final void Function(int assetId, String name) onAssetDetail;

  @override
  State<_LabelGroupTile> createState() => _LabelGroupTileState();
}

class _LabelGroupTileState extends State<_LabelGroupTile> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.group.isUnexplained;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = widget.group;
    final isUp = g.totalAmount >= 0;

    final Color borderColor;
    final Color bgColor;
    final Color labelColor;
    if (g.isUnexplained) {
      bgColor = Colors.orange.withValues(alpha: 0.06);
      borderColor = Colors.orange.withValues(alpha: 0.25);
      labelColor = Colors.orange.shade700;
    } else if (g.isExcluded) {
      bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.2);
      borderColor = cs.outline.withValues(alpha: 0.1);
      labelColor = cs.onSurface.withValues(alpha: 0.4);
    } else {
      bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.35);
      borderColor = cs.outline.withValues(alpha: 0.12);
      labelColor = cs.onSurface;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: _expanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (g.isUnexplained)
                              Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: Icon(Icons.help_outline,
                                    size: 14,
                                    color: Colors.orange.shade600),
                              ),
                            Text(
                              g.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: labelColor,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${g.assets.length}資産',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.4),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (g.isExcluded)
                    Text(
                      '${g.totalAmount >= 0 ? "+" : ""}¥${_fmt.format(g.totalAmount.abs())}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.35),
                          ),
                    )
                  else ...[
                    Icon(
                      isUp ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 13,
                      color: isUp ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '¥${_fmt.format(g.totalAmount.abs())}',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                            color: isUp ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(
              height: 1,
              color: cs.outline.withValues(alpha: 0.1),
              indent: 16,
              endIndent: 16,
            ),
            ...g.assets.map(
              (asset) => _AssetRowInGroup(
                asset: asset,
                labelEntries:
                    widget.labelEntries[asset.assetId] ?? [],
                isExcluded: g.isExcluded,
                onTap: () =>
                    widget.onLabelEdit(asset.assetId, asset.name, asset.diff),
                onLongPress: () => widget.onAssetDetail(
                  asset.isIncomeEntry ? asset.realAssetId : asset.assetId,
                  asset.name,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssetRowInGroup extends StatelessWidget {
  const _AssetRowInGroup({
    required this.asset,
    required this.labelEntries,
    required this.isExcluded,
    required this.onTap,
    required this.onLongPress,
  });

  final _AssetInGroup asset;
  final List<MonthlyLabelEntry> labelEntries;
  final bool isExcluded;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayAmount = asset.attributedAmount ?? asset.diff;
    final isUp = displayAmount >= 0;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isExcluded
                              ? cs.onSurface.withValues(alpha: 0.45)
                              : null,
                        ),
                  ),
                  if (!isExcluded) ...[
                    const SizedBox(height: 3),
                    _LabelBadge(
                      entries: labelEntries,
                      diff: asset.diff,
                      isExcluded: false,
                    ),
                  ],
                ],
              ),
            ),
            if (isExcluded)
              Text(
                '${asset.diff >= 0 ? "+" : ""}¥${_fmt.format(asset.diff.abs())}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.35),
                    ),
              )
            else ...[
              Icon(
                isUp ? Icons.arrow_upward : Icons.arrow_downward,
                size: 11,
                color: isUp ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 2),
              Text(
                '¥${_fmt.format(displayAmount.abs())}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isUp ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _LabelBadge extends StatelessWidget {
  const _LabelBadge({
    required this.entries,
    required this.diff,
    required this.isExcluded,
  });

  final List<MonthlyLabelEntry> entries;
  final int? diff;
  final bool isExcluded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (diff == null || diff == 0) return const SizedBox.shrink();

    if (isExcluded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.remove_circle_outline,
                size: 11, color: cs.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 4),
            Text(
              '収益から除外',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
            ),
          ],
        ),
      );
    }

    if (entries.isNotEmpty) {
      final first = entries.first;
      final amountText = first.amount != null
          ? ' ¥${_fmt.format(first.amount!.abs())}'
          : '';
      final extraText =
          entries.length > 1 ? ' +${entries.length - 1}件' : '';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.label_outline, size: 11, color: cs.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${first.label}$amountText$extraText',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_outline,
              size: 11, color: Colors.orange.shade600),
          const SizedBox(width: 4),
          Text(
            'タップしてラベル付け',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.orange.shade700,
                ),
          ),
        ],
      ),
    );
  }
}
