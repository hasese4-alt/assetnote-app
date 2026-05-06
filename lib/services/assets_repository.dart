import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:asset_note/utils/user_id.dart';

class MonthlyLabelEntry {
  const MonthlyLabelEntry({
    required this.label,
    required this.entryIndex,
    this.amount,
    this.excluded = false,
  });
  final String label;
  final int? amount; // null = 変動額全体を属する
  final int entryIndex;
  final bool excluded;
}

class AssetsRepository {
  AssetsRepository(this._client);

  final SupabaseClient _client;

Future<Map<String, dynamic>?> fetchMonthlyLock({
  required int year,
  required int month,
}) {
  final uid = Supabase.instance.client.auth.currentUser!.id;

  return _client
      .from('monthly_lock')
      .select()
      .eq('year', year)
      .eq('month', month)
      .eq('user_id', uid)
      .maybeSingle();
}

Future<void> upsertMonthlyLock({
  required int year,
  required int month,
  required bool confirmed,
}) async {
  final uid = Supabase.instance.client.auth.currentUser!.id;

  final updated = await _client
      .from('monthly_lock')
      .update({'confirmed': confirmed})
      .eq('year', year)
      .eq('month', month)
      .eq('user_id', uid)
      .select();

  if (updated.isEmpty) {
    await _client.from('monthly_lock').insert({
      'year': year,
      'month': month,
      'confirmed': confirmed,
      'user_id': uid,
    });
  }
}
  Future<void> updateMonthlyLock({
    required int year,
    required int month,
    required bool confirmed,
  }) {
    return _client
        .from('monthly_lock')
        .update({'confirmed': confirmed})
        .eq('year', year)
        .eq('month', month)
        .eq('user_id', userId);
  }

  // 現在の資産（JOIN でカテゴリ名取得）
  Future<List<Map<String, dynamic>>> fetchCurrentAssets() async {
    final uid = Supabase.instance.client.auth.currentUser!.id;

    final data = await _client
        .from('assets')
        .select('''
        id,
        name,
        value,
        acquisition_price,
        category1_id,
        category2_id,
        categories1(name, icon),
        categories2(name)
      ''')
        .eq('user_id', uid);

    return List<Map<String, dynamic>>.from(data);
  }

  // 過去の履歴（ID + name 両方取得）
  Future<List<Map<String, dynamic>>> fetchHistoryByDate(
    String snapshotDate,
  ) async {
    final data = await _client
        .from('assets_history')
        .select('''
          id,
          asset_id,
          name,
          value,
          acquisition_price,
          category1_id,
          category2_id,
          category1_name,
          category2_name,
          date
        ''')
        .eq('date', snapshotDate)
        .eq('user_id', userId);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> deleteCurrentAsset(int id) {
    return _client.from('assets').delete().eq('id', id).eq('user_id', userId);
  }

  Future<int?> fetchStartOfYearValue({
    required int assetId,
    required int year,
  }) async {
    final date = '$year-01-01';
    final data = await _client
        .from('assets_history')
        .select()
        .eq('asset_id', assetId)
        .eq('date', date)
        .eq('user_id', userId);
    if (data.isEmpty) return null;
    return data.first['value'] as int?;
  }

Future<List<Map<String, dynamic>>> fetchHistoryRaw({
  required DateTime from,
  required DateTime to,
  
}) async {
  // ★ DATE 型に合わせて "YYYY-MM-DD" に切る
  final fromDate = from.toIso8601String().substring(0, 10);
  final toDate = to.toIso8601String().substring(0, 10);

  final response = await _client
      .from('assets_history')
      .select()
      .gte('date', fromDate)
      .lte('date', toDate)
      .order('date', ascending: true);

  return response;
  
}


  Future<List<Map<String, dynamic>>> fetchStartOfYearHistory({
    required int year,
  }) async {
    final date = '$year-01-01';
    final data = await _client
        .from('assets_history')
        .select()
        .eq('date', date)
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> fetchPreviousMonthHistory({
    required int year,
    required int month,
  }) async {
    final previous = DateTime(year, month - 1);
    final previousYear = previous.year;
    final previousMonth = previous.month;

    final date = '$previousYear-${previousMonth.toString().padLeft(2, '0')}-01';

    final data = await _client
        .from('assets_history')
        .select('''
          id,
          asset_id,
          name,
          value,
          category1_id,
          category2_id,
          category1_name,
          category2_name,
          date
        ''')
        .eq('date', date)
        .eq('user_id', userId);

    return List<Map<String, dynamic>>.from(data);
  }

  /// Copies [fromYear/fromMonth] snapshot to the next month if next month has no records yet.
  Future<void> copySnapshotToNextMonth({
    required int fromYear,
    required int fromMonth,
  }) async {
    final fromDate = '$fromYear-${fromMonth.toString().padLeft(2, '0')}-01';
    final nextMonth = DateTime(fromYear, fromMonth + 1);
    final toDate =
        '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-01';

    final source = await _client
        .from('assets_history')
        .select()
        .eq('date', fromDate)
        .eq('user_id', userId);

    if (source.isEmpty) return;

    final existing = await _client
        .from('assets_history')
        .select('asset_id')
        .eq('date', toDate)
        .eq('user_id', userId);

    if (existing.isNotEmpty) return;

    final records = (source as List<dynamic>).map((a) {
      final m = Map<String, dynamic>.from(a as Map);
      return {
        'asset_id': m['asset_id'],
        'name': m['name'],
        'value': m['value'],
        'acquisition_price': m['acquisition_price'],
        'category1_id': m['category1_id'],
        'category2_id': m['category2_id'],
        'category1_name': m['category1_name'],
        'category2_name': m['category2_name'],
        'date': toDate,
        'user_id': userId,
      };
    }).toList();

    await _client
        .from('assets_history')
        .upsert(records, onConflict: 'asset_id, date');
  }

  /// Writes one [assets_history] row per current asset for the month snapshot date.
  /// [forceCurrentAssets] が true のとき、既存履歴を無視して assets テーブルを使う。
  Future<void> upsertMonthlySnapshot({
    required int year,
    required int month,
    bool forceCurrentAssets = false,
  }) async {
    final snapshotDate = '$year-${month.toString().padLeft(2, '0')}-01';

    final List<Map<String, dynamic>> sourceAssets;

    if (!forceCurrentAssets) {
      // ① その月の履歴があるか確認（過去月の手動編集を保持する場合）
      final existingHistory = await _client
          .from('assets_history')
          .select()
          .eq('date', snapshotDate)
          .eq('user_id', userId);

      if (existingHistory.isNotEmpty) {
        sourceAssets = List<Map<String, dynamic>>.from(existingHistory);
      } else {
        // 履歴なし → 現在の資産を使う
        final current = await _client
            .from('assets')
            .select('''
            id,
            name,
            value,
            category1_id,
            category2_id,
            categories1(name),
            categories2(name)
          ''')
            .eq('user_id', userId);
        sourceAssets = List<Map<String, dynamic>>.from(current);
      }
    } else {
      // 現在の assets テーブルの値を使う（現在月の確定）
      final current = await _client
          .from('assets')
          .select('''
          id,
          name,
          value,
          category1_id,
          category2_id,
          categories1(name),
          categories2(name)
        ''')
          .eq('user_id', userId);
      sourceAssets = List<Map<String, dynamic>>.from(current);
    }

    // ④ 一括 upsert
    final records = sourceAssets.map((a) {
      return {
        'asset_id': a['asset_id'] ?? a['id'],
        'name': a['name'],
        'value': a['value'],
        'acquisition_price': a['acquisition_price'],
        'category1_id': a['category1_id'],
        'category2_id': a['category2_id'],
        'category1_name': a['category1_name'] ?? a['categories1']?['name'],
        'category2_name': a['category2_name'] ?? a['categories2']?['name'],
        'date': snapshotDate,
        'user_id': userId,
      };
    }).toList();

    await _client
        .from('assets_history')
        .upsert(records, onConflict: 'asset_id, date');
  }

  Future<List<Map<String, dynamic>>> fetchAllMonthlyLocks() async {
    final uid = Supabase.instance.client.auth.currentUser!.id;

    final response = await _client
        .from('monthly_lock')
        .select()
        .eq('user_id', uid);

    final rows = response as List<dynamic>;

    return rows.map((e) => e as Map<String, dynamic>).toList();
  }

  /// categories1 + categories2 for add/edit asset forms (grouped by parent id).
  Future<
    ({
      List<Map<String, dynamic>> parentCategories,
      Map<String, List<Map<String, dynamic>>> childCategories,
    })
  >
  fetchCategoryHierarchy() async {
    final parents = await _client
        .from('categories1')
        .select('id, name, icon')
        .eq('user_id', userId);

    final children = await _client
        .from('categories2')
        .select('id, parent_id, name')
        .eq('user_id', userId);

    final map = <String, List<Map<String, dynamic>>>{};
    for (final c in children) {
      final pid = c['parent_id'] as String;
      map.putIfAbsent(pid, () => []);
      map[pid]!.add(Map<String, dynamic>.from(c));
    }

    return (
      parentCategories: List<Map<String, dynamic>>.from(parents),
      childCategories: map,
    );
  }

  Future<void> insertAsset({
    required String name,
    required int value,
    required String? category1Id,
    required String? category2Id,
    int? acquisitionPrice,
  }) async {
    await _client.from('assets').insert({
      'name': name,
      'value': value,
      'category1_id': category1Id,
      'category2_id': category2Id,
      'user_id': userId,
      if (acquisitionPrice != null) 'acquisition_price': acquisitionPrice,
    });
  }

  Future<void> insertAssetWithHistory({
    required String name,
    required int value,
    required String? category1Id,
    required String? category2Id,
    required String? category1Name,
    required String? category2Name,
    required int year,
    required int month,
    int? acquisitionPrice,
  }) async {
    final result = await _client
        .from('assets')
        .insert({
          'name': name,
          'value': value,
          'category1_id': category1Id,
          'category2_id': category2Id,
          'user_id': userId,
          if (acquisitionPrice != null) 'acquisition_price': acquisitionPrice,
        })
        .select('id')
        .single();

    final assetId = result['id'] as int;
    final snapshotDate = '$year-${month.toString().padLeft(2, '0')}-01';

    await _client.from('assets_history').insert({
      'asset_id': assetId,
      'name': name,
      'value': value,
      'category1_id': category1Id,
      'category2_id': category2Id,
      'category1_name': category1Name,
      'category2_name': category2Name,
      'date': snapshotDate,
      'user_id': userId,
      if (acquisitionPrice != null) 'acquisition_price': acquisitionPrice,
    });
  }

  Future<void> updateAsset({
    required int id,
    required String name,
    required int value,
    required String? category1Id,
    required String? category2Id,
    int? acquisitionPrice,
  }) async {
    await _client
        .from('assets')
        .update({
          'name': name,
          'value': value,
          'category1_id': category1Id,
          'category2_id': category2Id,
          'acquisition_price': acquisitionPrice,
        })
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<void> updateAssetsHistoryRow({
    required int id,
    required String name,
    required int value,
    int? acquisitionPrice,
  }) async {
    await _client
        .from('assets_history')
        .update({'name': name, 'value': value, 'acquisition_price': acquisitionPrice})
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<void> insertCategory1({required String name, String? icon}) async {
    await _client.from('categories1').insert({
      'user_id': userId,
      'name': name,
      if (icon != null) 'icon': icon,
    });
  }

  Future<void> updateCategory1({required String id, required String name, String? icon}) async {
    await _client.from('categories1').update({'name': name, 'icon': icon}).eq('id', id);
  }

  Future<void> deleteCategory1({required String id}) async {
    await _client.from('categories1').delete().eq('id', id);
  }

  Future<void> insertCategory2({
    required String parentId,
    required String name,
  }) async {
    await _client.from('categories2').insert({
      'user_id': userId,
      'parent_id': parentId,
      'name': name,
    });
  }

  Future<void> updateCategory2({required String id, required String name}) async {
    await _client.from('categories2').update({'name': name}).eq('id', id);
  }

  Future<void> deleteCategory2({required String id}) async {
    await _client.from('categories2').delete().eq('id', id);
  }

  Future<bool> hasLinkedAssets({
    required String category1Id,
    String? category2Id,
  }) async {
    var query = _client
        .from('assets')
        .select('id')
        .eq('category1_id', category1Id);

    if (category2Id != null) {
      query = query.eq('category2_id', category2Id);
    }

    final rows = await query.limit(1);
    return rows.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> fetchAssetHistorySnapshots(
    int assetId,
  ) async {
    final rows = await _client
        .from('assets_history')
        .select('id, asset_id, value, acquisition_price, date')
        .eq('asset_id', assetId)
        .eq('user_id', userId)
        .order('date', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> fetchAssetMemos(int assetId) async {
    final rows = await _client
        .from('asset_memos')
        .select()
        .eq('asset_id', assetId)
        .eq('user_id', userId)
        .order('memo_date', ascending: true);

    final memos = List<Map<String, dynamic>>.from(rows);
    final linkedIds = memos
        .where((m) => m['linked_asset_id'] != null)
        .map((m) => m['linked_asset_id'] as int)
        .toSet()
        .toList();

    if (linkedIds.isEmpty) return memos;

    final assets = await _client
        .from('assets')
        .select('id, name')
        .inFilter('id', linkedIds);
    final assetMap = {
      for (final a in assets) a['id'] as int: a['name'] as String,
    };

    return memos
        .map((m) => {
              ...m,
              if (m['linked_asset_id'] != null)
                'linked_asset_name': assetMap[m['linked_asset_id'] as int],
            })
        .toList();
  }

  Future<int> insertAssetMemo({
    required int assetId,
    required DateTime memoDate,
    required String memo,
    int? amount,
    bool isAuto = false,
    String? direction,
    int? linkedAssetId,
    bool isIncome = false,
  }) async {
    final result = await _client
        .from('asset_memos')
        .insert({
          'asset_id': assetId,
          'memo_date': memoDate.toIso8601String().substring(0, 10),
          'memo': memo,
          'amount': amount,
          'is_auto': isAuto,
          'user_id': userId,
          'direction': direction,
          'linked_asset_id': linkedAssetId,
          'is_income': isIncome,
        })
        .select('id')
        .single();
    return result['id'] as int;
  }

  Future<void> pairMemos(int id1, int id2) async {
    await Future.wait([
      _client
          .from('asset_memos')
          .update({'paired_memo_id': id2})
          .eq('id', id1),
      _client
          .from('asset_memos')
          .update({'paired_memo_id': id1})
          .eq('id', id2),
    ]);
  }

  Future<void> updateAssetMemo({
    required int id,
    required DateTime memoDate,
    required String memo,
    int? amount,
    String? direction,
    int? linkedAssetId,
    bool? isIncome,
  }) async {
    await _client
        .from('asset_memos')
        .update({
          'memo_date': memoDate.toIso8601String().substring(0, 10),
          'memo': memo,
          'amount': amount,
          'direction': direction,
          'linked_asset_id': linkedAssetId,
          if (isIncome != null) 'is_income': isIncome,
        })
        .eq('id', id)
        .eq('user_id', userId);
  }

  /// 他アセットのメモから linked_asset_id = assetId のものを取得（出側履歴候補用）
  Future<List<Map<String, dynamic>>> fetchMemosLinkedToAsset(
    int assetId,
  ) async {
    final rows = await _client
        .from('asset_memos')
        .select()
        .eq('linked_asset_id', assetId)
        .isFilter('paired_memo_id', null)
        .order('memo_date', ascending: true);

    final memos = List<Map<String, dynamic>>.from(rows);
    if (memos.isEmpty) return memos;

    final assetIds = memos.map((m) => m['asset_id'] as int).toSet().toList();
    final assets = await _client
        .from('assets')
        .select('id, name')
        .inFilter('id', assetIds);

    final assetMap = {
      for (final a in assets) a['id'] as int: a['name'] as String,
    };

    return memos
        .map((m) => {...m, 'from_asset_name': assetMap[m['asset_id'] as int]})
        .toList();
  }

  Future<void> deleteAssetMemo(int id) async {
    await _client
        .from('asset_memos')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> fetchIncomeMemosForMonth({
    required int year,
    required int month,
  }) async {
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final next = DateTime(year, month + 1);
    final to = '${next.year}-${next.month.toString().padLeft(2, '0')}-01';
    final rows = await _client
        .from('asset_memos')
        .select('id, asset_id, memo_date, memo, amount, direction')
        .eq('user_id', userId)
        .eq('is_income', true)
        .gte('memo_date', from)
        .lt('memo_date', to);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// labels と excluded を1クエリで返す
  Future<(Map<int, List<MonthlyLabelEntry>>, Set<int>)> fetchMonthlyMeta({
    required int year,
    required int month,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final rows = await _client
        .from('monthly_asset_labels')
        .select('asset_id, label, excluded, amount, entry_index')
        .eq('user_id', uid)
        .eq('year', year)
        .eq('month', month);
    final labels = <int, List<MonthlyLabelEntry>>{};
    final excluded = <int>{};
    for (final r in rows) {
      final id = (r['asset_id'] as num).toInt();
      // ラベルなし行の excluded のみ資産全体の除外とみなす
      if (r['excluded'] == true && r['label'] == null) excluded.add(id);
      if (r['label'] != null) {
        final entry = MonthlyLabelEntry(
          label: r['label'] as String,
          amount: (r['amount'] as num?)?.toInt(),
          entryIndex: (r['entry_index'] as num?)?.toInt() ?? 0,
          excluded: r['excluded'] as bool? ?? false,
        );
        labels.putIfAbsent(id, () => []).add(entry);
      }
    }
    for (final list in labels.values) {
      list.sort((a, b) => a.entryIndex.compareTo(b.entryIndex));
    }
    return (labels, excluded);
  }

  Future<void> upsertMonthlyLabel({
    required int assetId,
    required int year,
    required int month,
    required String label,
    int? amount,
    int entryIndex = 0,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    await _client.from('monthly_asset_labels').upsert(
      {
        'user_id': uid,
        'asset_id': assetId,
        'year': year,
        'month': month,
        'entry_index': entryIndex,
        'label': label.trim(),
        'amount': amount,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id, asset_id, year, month, entry_index',
    );
  }

  /// 既存ラベルを全削除してから新しいエントリーを一括 INSERT する。
  /// upsert の unique constraint 依存を避けるため delete+insert 方式を使用。
  Future<void> replaceMonthlyLabels({
    required int assetId,
    required int year,
    required int month,
    required List<MonthlyLabelEntry> entries,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    await _client
        .from('monthly_asset_labels')
        .delete()
        .eq('user_id', uid)
        .eq('asset_id', assetId)
        .eq('year', year)
        .eq('month', month);

    if (entries.isEmpty) return;
    final records = <Map<String, dynamic>>[
      for (int i = 0; i < entries.length; i++)
        {
          'user_id': uid,
          'asset_id': assetId,
          'year': year,
          'month': month,
          'entry_index': entries[i].entryIndex,
          'label': entries[i].label,
          'amount': entries[i].amount,
          'excluded': entries[i].excluded,
          'updated_at': DateTime.now().toIso8601String(),
        },
    ];
    await _client.from('monthly_asset_labels').insert(records);
  }

  Future<void> deleteMonthlyLabel({
    required int assetId,
    required int year,
    required int month,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    await _client
        .from('monthly_asset_labels')
        .delete()
        .eq('user_id', uid)
        .eq('asset_id', assetId)
        .eq('year', year)
        .eq('month', month);
  }

  Future<void> deleteMonthlyLabelEntry({
    required int assetId,
    required int year,
    required int month,
    required int entryIndex,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    await _client
        .from('monthly_asset_labels')
        .delete()
        .eq('user_id', uid)
        .eq('asset_id', assetId)
        .eq('year', year)
        .eq('month', month)
        .eq('entry_index', entryIndex);
  }

  Future<void> setMonthlyExclusion({
    required int assetId,
    required int year,
    required int month,
    required bool excluded,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    if (excluded) {
      await _client.from('monthly_asset_labels').upsert(
        {
          'user_id': uid,
          'asset_id': assetId,
          'year': year,
          'month': month,
          'entry_index': 0,
          'excluded': true,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id, asset_id, year, month, entry_index',
      );
    } else {
      await _client
          .from('monthly_asset_labels')
          .update({'excluded': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('user_id', uid)
          .eq('asset_id', assetId)
          .eq('year', year)
          .eq('month', month)
          .not('label', 'is', null);
      await _client
          .from('monthly_asset_labels')
          .delete()
          .eq('user_id', uid)
          .eq('asset_id', assetId)
          .eq('year', year)
          .eq('month', month)
          .isFilter('label', null);
    }
  }

  /// 指定月の assets_history と monthly_lock を削除し、前月末の状態をコピーして初期化する。
  Future<void> resetMonthData({
    required int year,
    required int month,
  }) async {
    final date = '$year-${month.toString().padLeft(2, '0')}-01';

    await _client
        .from('assets_history')
        .delete()
        .eq('date', date)
        .eq('user_id', userId);

    await _client
        .from('monthly_lock')
        .delete()
        .eq('year', year)
        .eq('month', month)
        .eq('user_id', userId);

    final prevMonth = DateTime(year, month - 1);
    await copySnapshotToNextMonth(
      fromYear: prevMonth.year,
      fromMonth: prevMonth.month,
    );

    // 前月スナップショットが存在しなかった場合のフォールバック:
    // 現在の assets テーブルから当月スナップショットを作成する
    final created = await _client
        .from('assets_history')
        .select('asset_id')
        .eq('date', date)
        .eq('user_id', userId);

    if (created.isEmpty) {
      await upsertMonthlySnapshot(
        year: year,
        month: month,
        forceCurrentAssets: true,
      );
    }
  }
}
