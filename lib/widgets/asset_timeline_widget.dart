import 'package:asset_note/services/assets_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _fmt = NumberFormat('#,###', 'ja_JP');

/// 1資産のタイムライン（スナップショット + メモ + 履歴候補）を表示し、
/// メモ追加・編集ダイアログもこのウィジェットが管理する。
class AssetTimeline extends StatefulWidget {
  const AssetTimeline({
    super.key,
    required this.assetId,
    required this.assetName,
  });

  final int assetId;
  final String assetName;

  @override
  State<AssetTimeline> createState() => _AssetTimelineState();
}

class _AssetTimelineState extends State<AssetTimeline> {
  late final AssetsRepository _repository;
  List<Map<String, dynamic>> _memos = [];
  List<Map<String, dynamic>> _snapshots = [];
  List<Map<String, dynamic>> _linkedMemos = [];
  List<Map<String, dynamic>> _allAssets = [];
  Set<String> _confirmedMonthKeys = {}; // "YYYY-MM" 形式

  @override
  void initState() {
    super.initState();
    _repository = AssetsRepository(Supabase.instance.client);
    _loadTimeline();
    _loadAllAssets();
  }

  Future<void> _loadAllAssets() async {
    final assets = await _repository.fetchCurrentAssets();
    if (!mounted) return;
    setState(() => _allAssets = assets);
  }

  Future<void> _loadTimeline() async {
    final results = await Future.wait([
      _repository.fetchAssetMemos(widget.assetId),
      _repository.fetchAssetHistorySnapshots(widget.assetId),
      _repository.fetchMemosLinkedToAsset(widget.assetId),
      _repository.fetchAllMonthlyLocks(),
    ]);
    if (!mounted) return;

    final memos = List<Map<String, dynamic>>.from(results[0]);
    final snapshots = List<Map<String, dynamic>>.from(results[1]);
    final linkedMemos = List<Map<String, dynamic>>.from(results[2]);
    final lockRows = List<Map<String, dynamic>>.from(results[3]);

    final confirmedKeys = lockRows
        .where((r) => r['confirmed'] == true)
        .map<String>((r) {
          final y = r['year'] as int;
          final m = (r['month'] as int).toString().padLeft(2, '0');
          return '$y-$m';
        })
        .toSet();

    final didInsert = await _generateAutoMemosIfNeeded(
      memos: memos,
      snapshots: snapshots,
    );

    if (!mounted) return;

    if (didInsert) {
      final refreshed = await _repository.fetchAssetMemos(widget.assetId);
      if (!mounted) return;
      setState(() {
        _memos = List<Map<String, dynamic>>.from(refreshed);
        _snapshots = snapshots;
        _linkedMemos = linkedMemos;
        _confirmedMonthKeys = confirmedKeys;
      });
    } else {
      setState(() {
        _memos = memos;
        _snapshots = snapshots;
        _linkedMemos = linkedMemos;
        _confirmedMonthKeys = confirmedKeys;
      });
    }
  }

  Future<bool> _generateAutoMemosIfNeeded({
    required List<Map<String, dynamic>> memos,
    required List<Map<String, dynamic>> snapshots,
  }) async {
    // 取得価格がある最初のスナップショットを探す
    final sortedSnaps = [...snapshots]
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    final firstAcqSnap = sortedSnaps.isNotEmpty &&
            sortedSnaps[0]['acquisition_price'] != null
        ? sortedSnaps[0]
        : null;

    // スナップショットが2件未満かつ取得価格もない場合は不要
    if (snapshots.length < 2 && firstAcqSnap == null) return false;

    // 各区間ごとに「あるべき自動メモ」を計算する
    final desired = <({DateTime date, int amount})>[];
    for (int i = 0; i < snapshots.length - 1; i++) {
      final prevDate = DateTime.parse(snapshots[i]['date'] as String);
      final nextDate = DateTime.parse(snapshots[i + 1]['date'] as String);
      final prevValue = (snapshots[i]['value'] as num).toInt();
      final nextValue = (snapshots[i + 1]['value'] as num).toInt();
      // 自動メモは nextDate の月末（例: 4/30）に配置する
      final lastDay = DateTime(nextDate.year, nextDate.month + 1, 0);
      // スナップショットは YYYY-MM-01 で保存されているが実態は月末残高なので
      // メモの対象区間は prevDate の月末翌日 〜 nextDate の月末とする
      final prevLastDay = DateTime(prevDate.year, prevDate.month + 1, 0);

      // 取得価格がある月のメモは取得期間自動メモで消化するため除外
      final isAcqMonth = firstAcqSnap != null &&
          snapshots[i]['date'] == firstAcqSnap['date'];

      final sumMemoAmounts = isAcqMonth
          ? 0
          : memos
              .where((m) {
                final d = DateTime.parse(m['memo_date'] as String);
                return d.isAfter(prevLastDay) &&
                    !d.isAfter(lastDay) &&
                    m['is_auto'] != true &&
                    m['amount'] != null;
              })
              .fold<int>(0, (sum, m) {
                final amt = m['amount'] as int;
                final dir = m['direction'] as String?;
                return sum + (dir == '出' ? -amt : amt);
              });

      desired.add((date: lastDay, amount: (nextValue - prevValue) - sumMemoAmounts));
    }

    // 取得価格 → 最初のスナップショットの自動メモ（取得月の未説明差額）
    if (firstAcqSnap != null) {
      final acqPrice = (firstAcqSnap['acquisition_price'] as num).toInt();
      final snapValue = (firstAcqSnap['value'] as num).toInt();
      final snapDate = DateTime.parse(firstAcqSnap['date'] as String);
      final lastDay = DateTime(snapDate.year, snapDate.month + 1, 0);
      final nextMonth = DateTime(snapDate.year, snapDate.month + 1);

      // 取得月（snapDate 以降、翌月初め未満）のメモ合計
      final sumMemoAmounts = memos
          .where((m) {
            final d = DateTime.parse(m['memo_date'] as String);
            return !d.isBefore(snapDate) &&
                d.isBefore(nextMonth) &&
                m['is_auto'] != true &&
                m['amount'] != null;
          })
          .fold<int>(0, (sum, m) {
            final amt = m['amount'] as int;
            final dir = m['direction'] as String?;
            return sum + (dir == '出' ? -amt : amt);
          });

      final acqAutoAmount = (snapValue - acqPrice) - sumMemoAmounts;
      // 差額が 0 の場合（メモで完全説明済み）は不要
      if (acqAutoAmount != 0) {
        desired.add((date: lastDay, amount: acqAutoAmount));
      }
    }

    // 既存の自動メモと照合（日付・金額が完全一致なら何もしない）
    final existingAuto = (memos.where((m) => m['is_auto'] == true).toList())
      ..sort((a, b) =>
          (a['memo_date'] as String).compareTo(b['memo_date'] as String));

    final sortedDesired = [...desired]..sort((a, b) => a.date.compareTo(b.date));

    bool matches = existingAuto.length == sortedDesired.length;
    if (matches) {
      for (int i = 0; i < sortedDesired.length; i++) {
        final d = DateTime.parse(existingAuto[i]['memo_date'] as String);
        final want = sortedDesired[i];
        if (d.year != want.date.year ||
            d.month != want.date.month ||
            d.day != want.date.day ||
            (existingAuto[i]['amount'] as int?) != want.amount) {
          matches = false;
          break;
        }
      }
    }

    if (matches) return false;

    // 不一致：既存の自動メモを全削除して正しい内容で再生成
    // is_income フラグを日付キーで保持して再生成後に引き継ぐ
    final incomeByDate = <String, bool>{};
    for (final m in existingAuto) {
      if (m['is_income'] == true) {
        incomeByDate[m['memo_date'] as String] = true;
      }
    }

    for (final m in existingAuto) {
      await _repository.deleteAssetMemo(m['id'] as int);
    }
    for (final d in sortedDesired) {
      final newId = await _repository.insertAssetMemo(
        assetId: widget.assetId,
        memoDate: d.date,
        memo: d.amount >= 0 ? '増加' : '減少',
        amount: d.amount,
        isAuto: true,
      );
      final dateKey = d.date.toIso8601String().substring(0, 10);
      if (incomeByDate.containsKey(dateKey)) {
        await _repository.updateAssetMemo(
          id: newId,
          memoDate: d.date,
          memo: d.amount >= 0 ? '増加' : '減少',
          amount: d.amount,
          isIncome: true,
        );
      }
    }

    return true;
  }

  // スナップショットは YYYY-MM-01 で保存されているが表示は月末日なので、
  // ソート用にも末日換算した文字列を返す
  String _sortKey(Map<String, dynamic> item) {
    final dateStr = item['date'] as String;
    if (item['type'] == 'snapshot') {
      final d = DateTime.parse(dateStr);
      if (d.day == 1) {
        final lastDay = DateTime(d.year, d.month + 1, 0);
        return lastDay.toIso8601String().substring(0, 10);
      }
    }
    return dateStr;
  }

  // 同日内の順序: 取得価格(-1) → 自動メモ(0) → ユーザーメモ/入出(1) → 確定額(2)
  int _typePriority(Map<String, dynamic> item) {
    if (item['type'] == 'snapshot') return 2;
    if (item['type'] == 'acquisition') return -1;
    if (item['is_auto'] == true) return 0;
    return 1;
  }

  List<Map<String, dynamic>> get _mergedTimeline {
    final items = <Map<String, dynamic>>[
      for (final s in _snapshots)
        {'type': 'snapshot', 'date': s['date'] as String, 'value': s['value']},
      for (final m in _memos)
        {'type': 'memo', 'date': m['memo_date'] as String, ...m},
      for (final lm in _linkedMemos)
        {'type': 'linked_memo', 'date': lm['memo_date'] as String, ...lm},
    ];

    // 取得価格が設定されている最初のスナップショットを取得価格エントリとして挿入
    final acqSnapshots = _snapshots
        .where((s) => s['acquisition_price'] != null)
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    if (acqSnapshots.isNotEmpty) {
      final first = acqSnapshots.first;
      items.add({
        'type': 'acquisition',
        'date': first['date'] as String,
        'acquisition_price': first['acquisition_price'],
      });
    }
    items.sort((a, b) {
      final dateCmp = _sortKey(a).compareTo(_sortKey(b));
      if (dateCmp != 0) return dateCmp;
      return _typePriority(a).compareTo(_typePriority(b));
    });

    final result = <Map<String, dynamic>>[];
    int? lastYear;
    for (final item in items) {
      final year = DateTime.parse(item['date'] as String).year;
      if (lastYear != year) {
        result.add({'type': 'year_divider', 'year': year});
        lastYear = year;
      }
      result.add(item);
    }
    return result;
  }

  Future<void> _openMemoDialog({
    Map<String, dynamic>? existing,
    Map<String, dynamic>? prefill,
    bool hideLinkedAssetPicker = false,
    int? sourceLinkedMemoId,
  }) async {
    final init = existing ?? prefill ?? {};
    DateTime selectedDate = init['memo_date'] != null
        ? DateTime.parse(init['memo_date'] as String)
        : DateTime.now();
    final memoController = TextEditingController(
      text: init['memo'] as String? ?? '',
    );
    final amountController = TextEditingController(
      text: init['amount']?.toString() ?? '',
    );
    String? selectedDirection = init['direction'] as String?;
    int? selectedLinkedAssetId = init['linked_asset_id'] as int?;
    bool selectedIsIncome = (init['is_income'] as bool?) ?? false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existing == null ? 'メモを追加' : 'メモを編集',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setModalState(() => selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(ctx)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.4),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${selectedDate.month}/${selectedDate.day}',
                            style: Theme.of(ctx).textTheme.bodyLarge,
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DirectionSelector(
                    value: selectedDirection,
                    onChanged: (v) => setModalState(() {
                      selectedDirection = v;
                      if (v != '入') selectedLinkedAssetId = null;
                    }),
                  ),
                  if (!hideLinkedAssetPicker &&
                      (selectedDirection == '入' ||
                          selectedDirection == '出')) ...[
                    const SizedBox(height: 12),
                    _AssetPickerRow(
                      label: selectedDirection == '入' ? '出元アセット' : '入先アセット',
                      pickerTitle:
                          selectedDirection == '入' ? '出元アセットを選択' : '入先アセットを選択',
                      allAssets: _allAssets.where((a) {
                        final rawId = a['id'];
                        final id =
                            rawId is int ? rawId : (rawId as num).toInt();
                        return id != widget.assetId;
                      }).toList(),
                      selectedAssetId: selectedLinkedAssetId,
                      onChanged: (id) =>
                          setModalState(() => selectedLinkedAssetId = id),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      hintText: '金額（任意）',
                      prefixText: '¥ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Theme.of(ctx)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: memoController,
                    autofocus: true,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '例：10万円積み立て',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Theme.of(ctx)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  if (amountController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(ctx)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
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
                                Text(
                                  '収益に含める',
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '分析ページの内訳に計上します',
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Theme.of(ctx)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.45),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: selectedIsIncome,
                            onChanged: (v) =>
                                setModalState(() => selectedIsIncome = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (existing != null) ...[
                        OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _repository
                                .deleteAssetMemo(existing['id'] as int);
                            _loadTimeline();
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
                          onPressed: () async {
                            final text = memoController.text.trim();
                            if (text.isEmpty) return;
                            final amount = int.tryParse(
                              amountController.text.trim().replaceAll(',', ''),
                            );
                            Navigator.pop(ctx);
                            if (existing == null) {
                              final newId = await _repository.insertAssetMemo(
                                assetId: widget.assetId,
                                memoDate: selectedDate,
                                memo: text,
                                amount: amount,
                                direction: selectedDirection,
                                linkedAssetId: selectedLinkedAssetId,
                                isIncome: selectedIsIncome,
                              );
                              if (sourceLinkedMemoId != null) {
                                await _repository.pairMemos(
                                  newId,
                                  sourceLinkedMemoId,
                                );
                              }
                            } else {
                              await _repository.updateAssetMemo(
                                id: existing['id'] as int,
                                memoDate: selectedDate,
                                memo: text,
                                amount: amount,
                                direction: selectedDirection,
                                linkedAssetId: selectedLinkedAssetId,
                                isIncome: selectedIsIncome,
                              );
                            }
                            _loadTimeline();
                          },
                          style: FilledButton.styleFrom(
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('保存'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeline = _mergedTimeline;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '履歴・メモ',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            TextButton.icon(
              onPressed: () => _openMemoDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('メモ追加'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (timeline.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '履歴・メモはまだありません',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
            ),
          )
        else
          _TimelineList(
            items: timeline,
            snapshots: _snapshots,
            confirmedMonthKeys: _confirmedMonthKeys,
            onMemoTap: (memo) => _openMemoDialog(existing: memo),
            onLinkedMemoTap: (lm) => _openMemoDialog(
              prefill: {
                'memo_date': lm['memo_date'],
                'memo': lm['memo'],
                'amount': lm['amount'],
                'direction': '出',
                'linked_asset_id': lm['asset_id'],
              },
              hideLinkedAssetPicker: true,
              sourceLinkedMemoId: lm['id'] as int,
            ),
          ),
      ],
    );
  }
}

// ─── タイムラインリスト ────────────────────────────────────────────────────────

class _TimelineList extends StatelessWidget {
  const _TimelineList({
    required this.items,
    required this.snapshots,
    required this.confirmedMonthKeys,
    required this.onMemoTap,
    required this.onLinkedMemoTap,
  });

  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> snapshots;
  final Set<String> confirmedMonthKeys;
  final void Function(Map<String, dynamic>) onMemoTap;
  final void Function(Map<String, dynamic>) onLinkedMemoTap;

  Map<String, int?> _buildPrevValueMap() {
    final map = <String, int?>{};
    for (var i = 0; i < snapshots.length; i++) {
      final dateKey = snapshots[i]['date'] as String;
      map[dateKey] = i > 0 ? snapshots[i - 1]['value'] as int? : null;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final prevMap = _buildPrevValueMap();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(items.length, (i) {
        final item = items[i];

        if (item['type'] == 'year_divider') {
          return Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: Text(
              '${item['year']}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
            ),
          );
        }

        final isSnapshot = item['type'] == 'snapshot';
        final isAcquisition = item['type'] == 'acquisition';
        final isLast = i == items.length - 1 ||
            (i == items.length - 2 && items[i + 1]['type'] == 'year_divider');

        final prevValue = isSnapshot ? prevMap[item['date'] as String] : null;

        // "YYYY-MM-01" → "YYYY-MM" でロック照合
        final isConfirmed = isSnapshot &&
            confirmedMonthKeys
                .contains((item['date'] as String).substring(0, 7));

        final dotColor = isSnapshot
            ? (isConfirmed ? colorScheme.primary : Colors.amber.shade600)
            : isAcquisition
                ? Colors.green.shade600
                : colorScheme.primary.withValues(alpha: 0.5);

        final dotSize = isSnapshot
            ? 12.0
            : isAcquisition
                ? 10.0
                : 8.0;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                child: Column(
                  children: [
                    Container(
                      width: dotSize,
                      height: dotSize,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        border: isSnapshot
                            ? Border.all(color: colorScheme.surface, width: 2)
                            : null,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1.5,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: isSnapshot
                      ? SnapshotCard(
                          date: DateTime.parse(item['date'] as String),
                          value: item['value'] as int,
                          prevValue: prevValue,
                          isConfirmed: isConfirmed,
                        )
                      : isAcquisition
                          ? AcquisitionCard(item: item)
                          : item['type'] == 'linked_memo'
                              ? LinkedMemoCard(
                                  item: item,
                                  onTap: () => onLinkedMemoTap(item),
                                )
                              : MemoCard(
                                  item: item,
                                  onTap: () => onMemoTap(item),
                                ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─── 取得価格カード ────────────────────────────────────────────────────────────

class AcquisitionCard extends StatelessWidget {
  const AcquisitionCard({super.key, required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(item['date'] as String);
    final price = (item['acquisition_price'] as num).toInt();
    final displayDate = DateTime(date.year, date.month, 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(
            '${displayDate.month}/${displayDate.day}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '取得価格',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Text(
            '¥${_fmt.format(price)}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
            ),
            child: Text(
              '取得',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── スナップショットカード ───────────────────────────────────────────────────

class SnapshotCard extends StatelessWidget {
  const SnapshotCard({
    super.key,
    required this.date,
    required this.value,
    required this.prevValue,
    required this.isConfirmed,
  });

  final DateTime date;
  final int value;
  final int? prevValue;
  final bool isConfirmed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final diff = prevValue != null ? value - prevValue! : null;
    final isUp = diff != null && diff >= 0;

    // スナップショットは YYYY-MM-01 で保存されているが実態は月末残高なので末日で表示
    final displayDate = date.day == 1
        ? DateTime(date.year, date.month + 1, 0)
        : date;

    // 仮カード・自動メモ用（白背景での緑・赤）
    final diffColor = isUp ? Colors.green.shade700 : Colors.red.shade700;

    if (isConfirmed) {
      // 確定済み：青みがかった背景＋塗り潰しバッジで自動メモと明確に区別
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Text(
              '${displayDate.month}/${displayDate.day}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '¥${_fmt.format(value)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
              ),
            ),
            if (diff != null) ...[
              Icon(
                isUp ? Icons.arrow_upward : Icons.arrow_downward,
                size: 11,
                color: diffColor,
              ),
              const SizedBox(width: 2),
              Text(
                '¥${_fmt.format(diff.abs())}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: diffColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '確定',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
              ),
            ),
          ],
        ),
      );
    } else {
      // 未確定：アンバーボーダーで「仮」バッジ
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade600.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Text(
              '${displayDate.month}/${displayDate.day}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.amber.shade700,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '¥${_fmt.format(value)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (diff != null) ...[
              Icon(
                isUp ? Icons.arrow_upward : Icons.arrow_downward,
                size: 11,
                color: diffColor,
              ),
              const SizedBox(width: 2),
              Text(
                '¥${_fmt.format(diff.abs())}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: diffColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.amber.shade600.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                '仮',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      );
    }
  }
}

// ─── メモカード ───────────────────────────────────────────────────────────────

class MemoCard extends StatelessWidget {
  const MemoCard({super.key, required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final date = DateTime.parse(item['date'] as String);
    final isAuto = item['is_auto'] == true;
    final amount = item['amount'] as int?;
    final direction = item['direction'] as String?;
    final isOut = direction == '出';
    final isIn = direction == '入';
    final linkedAssetName = item['linked_asset_name'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: isAuto
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 7)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isAuto
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: isAuto
              ? Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.15),
                  strokeAlign: BorderSide.strokeAlignInside,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${date.month}/${date.day}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary
                            .withValues(alpha: isAuto ? 0.5 : 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item['memo'] as String,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isAuto
                              ? colorScheme.onSurface.withValues(alpha: 0.5)
                              : null,
                          fontStyle:
                              isAuto ? FontStyle.italic : FontStyle.normal,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (direction != null) ...[
                  const SizedBox(width: 6),
                  DirectionBadge(direction: direction),
                ],
                if (amount != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${isOut ? '−' : isIn ? '+' : ''}¥${_fmt.format(amount.abs())}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isAuto
                              ? colorScheme.onSurface.withValues(alpha: 0.45)
                              : isOut
                                  ? Colors.red
                                  : isIn
                                      ? Colors.green
                                      : colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                if (item['is_income'] == true) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: Colors.teal.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      '収益',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.teal.shade700,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                    ),
                  ),
                ],
                if (isAuto) ...[
                  const SizedBox(width: 6),
                  Text(
                    '自動',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.3),
                          fontSize: 10,
                        ),
                  ),
                ],
              ],
            ),
            if (linkedAssetName != null) ...[
              const SizedBox(height: 4),
              Text(
                isOut ? '→ $linkedAssetName' : '← $linkedAssetName',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 入出バッジ ───────────────────────────────────────────────────────────────

class DirectionBadge extends StatelessWidget {
  const DirectionBadge({super.key, required this.direction});

  final String direction;

  @override
  Widget build(BuildContext context) {
    final isOut = direction == '出';
    final color = isOut ? Colors.red : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        direction,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
      ),
    );
  }
}

// ─── 出側履歴候補カード ────────────────────────────────────────────────────────

class LinkedMemoCard extends StatelessWidget {
  const LinkedMemoCard({super.key, required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final date = DateTime.parse(item['date'] as String);
    final amount = item['amount'] as int?;
    final fromAssetName = item['from_asset_name'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${date.month}/${date.day}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item['memo'] as String,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const DirectionBadge(direction: '出'),
                if (amount != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '−¥${_fmt.format(amount.abs())}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '履歴候補',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.orange.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (fromAssetName != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '← $fromAssetName',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 入出セレクター ───────────────────────────────────────────────────────────

class _DirectionSelector extends StatelessWidget {
  const _DirectionSelector({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Text(
          '入出',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(width: 12),
        _DirectionChip(
          label: 'なし',
          selected: value == null,
          selectedColor: colorScheme.primary,
          onTap: () => onChanged(null),
        ),
        const SizedBox(width: 8),
        _DirectionChip(
          label: '入',
          selected: value == '入',
          selectedColor: Colors.green,
          onTap: () => onChanged(value == '入' ? null : '入'),
        ),
        const SizedBox(width: 8),
        _DirectionChip(
          label: '出',
          selected: value == '出',
          selectedColor: Colors.red,
          onTap: () => onChanged(value == '出' ? null : '出'),
        ),
      ],
    );
  }
}

class _DirectionChip extends StatelessWidget {
  const _DirectionChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.15)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? selectedColor.withValues(alpha: 0.6)
                : colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected
                    ? selectedColor
                    : colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

// ─── アセットピッカー行 ───────────────────────────────────────────────────────

class _AssetPickerRow extends StatelessWidget {
  const _AssetPickerRow({
    required this.allAssets,
    required this.selectedAssetId,
    required this.onChanged,
    this.label = '出元アセット',
    this.pickerTitle = '出元アセットを選択',
  });

  final List<Map<String, dynamic>> allAssets;
  final int? selectedAssetId;
  final ValueChanged<int?> onChanged;
  final String label;
  final String pickerTitle;

  String? _selectedName() {
    if (selectedAssetId == null) return null;
    for (final a in allAssets) {
      final id = a['id'] is int ? a['id'] as int : (a['id'] as num).toInt();
      if (id == selectedAssetId) return a['name'] as String?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = _selectedName();

    return GestureDetector(
      onTap: () async {
        final picked = await showModalBottomSheet<int?>(
          context: context,
          backgroundColor: colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => _AssetPickerSheet(
            allAssets: allAssets,
            selectedAssetId: selectedAssetId,
            title: pickerTitle,
          ),
        );
        if (picked != null) onChanged(picked == -1 ? null : picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 16,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const Spacer(),
            Text(
              name ?? '未設定',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: name != null
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetPickerSheet extends StatelessWidget {
  const _AssetPickerSheet({
    required this.allAssets,
    required this.selectedAssetId,
    this.title = '出元アセットを選択',
  });

  final List<Map<String, dynamic>> allAssets;
  final int? selectedAssetId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (selectedAssetId != null)
                TextButton(
                  onPressed: () => Navigator.pop(context, -1),
                  child: const Text('クリア'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allAssets.length,
            itemBuilder: (ctx, i) {
              final a = allAssets[i];
              final id =
                  a['id'] is int ? a['id'] as int : (a['id'] as num).toInt();
              final isSelected = id == selectedAssetId;
              return ListTile(
                title: Text(a['name'] as String),
                trailing: isSelected
                    ? Icon(Icons.check, color: colorScheme.primary, size: 18)
                    : null,
                onTap: () => Navigator.pop(context, id),
              );
            },
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }
}
