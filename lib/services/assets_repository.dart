import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:asset_note/utils/user_id.dart';

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
        is_sold,
        acquisition_price,
        category1_id,
        category2_id,
        icon_label,
        icon_text_color,
        icon_bg_color,
        hide_favicon,
        categories1(name, icon),
        categories2(name)
      ''')
        .eq('user_id', uid);

    return data.map((row) {
      final m = Map<String, dynamic>.from(row);
      final c1 = m['categories1'] as Map?;
      final c2 = m['categories2'] as Map?;
      m['category1_name'] = c1?['name'] as String?;
      m['category1_icon'] = c1?['icon'] as String?;
      m['category2_name'] = c2?['name'] as String?;
      return m;
    }).toList();
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
          is_sold,
          acquisition_price,
          category1_id,
          category2_id,
          category1_name,
          category2_name,
          icon_label,
          icon_text_color,
          icon_bg_color,
          date
        ''')
        .eq('date', snapshotDate)
        .eq('user_id', userId);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> deleteCurrentAsset(int id) {
    return _client.from('assets').delete().eq('id', id).eq('user_id', userId);
  }

  Future<void> deleteHistoryRow(int historyId) {
    return _client.from('assets_history').delete().eq('id', historyId).eq('user_id', userId);
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
      .eq('user_id', userId)
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

    final records = (source as List<dynamic>)
        .where((a) => (a as Map<String, dynamic>)['is_sold'] != true)
        .map((a) {
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
            'icon_label': m['icon_label'],
            'icon_text_color': m['icon_text_color'],
            'icon_bg_color': m['icon_bg_color'],
            'date': toDate,
            'user_id': userId,
          };
        }).toList();

    if (records.isEmpty) return;
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
            is_sold,
            acquisition_price,
            category1_id,
            category2_id,
            icon_label,
            icon_text_color,
            icon_bg_color,
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
          is_sold,
          acquisition_price,
          category1_id,
          category2_id,
          icon_label,
          icon_text_color,
          icon_bg_color,
          hide_favicon,
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
        'is_sold': a['is_sold'] ?? false,
        'acquisition_price': a['acquisition_price'],
        'category1_id': a['category1_id'],
        'category2_id': a['category2_id'],
        'category1_name': a['category1_name'] ?? a['categories1']?['name'],
        'category2_name': a['category2_name'] ?? a['categories2']?['name'],
        'icon_label': a['icon_label'],
        'icon_text_color': a['icon_text_color'],
        'icon_bg_color': a['icon_bg_color'],
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
        .select('id, parent_id, name, hide_favicon')
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
    String? iconLabel,
    String? iconTextColor,
    String? iconBgColor,
    bool hideFavicon = false,
  }) async {
    await _client.from('assets').insert({
      'name': name,
      'value': value,
      'category1_id': category1Id,
      'category2_id': category2Id,
      'user_id': userId,
      'acquisition_price': ?acquisitionPrice,
      if (iconLabel != null && iconLabel.isNotEmpty) 'icon_label': iconLabel,
      'icon_text_color': ?iconTextColor,
      'icon_bg_color': ?iconBgColor,
      'hide_favicon': hideFavicon,
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
    String? iconLabel,
    String? iconTextColor,
    String? iconBgColor,
    bool hideFavicon = false,
  }) async {
    final result = await _client
        .from('assets')
        .insert({
          'name': name,
          'value': value,
          'category1_id': category1Id,
          'category2_id': category2Id,
          'user_id': userId,
          'acquisition_price': ?acquisitionPrice,
          if (iconLabel != null && iconLabel.isNotEmpty) 'icon_label': iconLabel,
          'icon_text_color': ?iconTextColor,
          'icon_bg_color': ?iconBgColor,
          'hide_favicon': hideFavicon,
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
      'acquisition_price': ?acquisitionPrice,
      if (iconLabel != null && iconLabel.isNotEmpty) 'icon_label': iconLabel,
      'icon_text_color': ?iconTextColor,
      'icon_bg_color': ?iconBgColor,
    });
  }

  Future<void> updateAsset({
    required int id,
    required String name,
    required int value,
    required String? category1Id,
    required String? category2Id,
    int? acquisitionPrice,
    String? iconLabel,
    String? iconTextColor,
    String? iconBgColor,
    bool hideFavicon = false,
  }) async {
    await _client
        .from('assets')
        .update({
          'name': name,
          'value': value,
          'category1_id': category1Id,
          'category2_id': category2Id,
          'acquisition_price': acquisitionPrice,
          'icon_label': iconLabel?.isNotEmpty == true ? iconLabel : null,
          'icon_text_color': iconTextColor,
          'icon_bg_color': iconBgColor,
          'hide_favicon': hideFavicon,
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
      'icon': ?icon,
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
    bool hideFavicon = false,
  }) async {
    await _client.from('categories2').insert({
      'user_id': userId,
      'parent_id': parentId,
      'name': name,
      'hide_favicon': hideFavicon,
    });
  }

  Future<void> updateCategory2({
    required String id,
    required String name,
    bool hideFavicon = false,
  }) async {
    await _client.from('categories2').update({
      'name': name,
      'hide_favicon': hideFavicon,
    }).eq('id', id);
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
    int? sellPrice,
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
          'sell_price': sellPrice,
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
          'is_income': ?isIncome,
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

  Future<List<Map<String, dynamic>>> fetchIncomeMemosForYear({
    required int year,
  }) async {
    final from = '$year-01-01';
    final to = '${year + 1}-01-01';
    final rows = await _client
        .from('asset_memos')
        .select('id, asset_id, memo_date, memo, amount, direction, sell_price')
        .eq('user_id', userId)
        .eq('is_income', true)
        .gte('memo_date', from)
        .lt('memo_date', to);
    return List<Map<String, dynamic>>.from(rows);
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
        .select('id, asset_id, memo_date, memo, amount, direction, sell_price')
        .eq('user_id', userId)
        .eq('is_income', true)
        .gte('memo_date', from)
        .lt('memo_date', to);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> sellAsset({
    required int assetId,
    required String assetName,
    required int sellPrice,
    required int acquisitionPrice,
    DateTime? memoDate,
  }) async {
    final profit = sellPrice - acquisitionPrice;
    await insertAssetMemo(
      assetId: assetId,
      memoDate: memoDate ?? DateTime.now(),
      memo: '売却: $assetName',
      amount: profit.abs(),
      direction: profit >= 0 ? '入' : '出',
      isIncome: true,
      sellPrice: sellPrice,
    );
    await _client
        .from('assets')
        .update({'value': 0, 'is_sold': true, 'acquisition_price': acquisitionPrice})
        .eq('id', assetId)
        .eq('user_id', userId);
  }

  Future<void> unsellAsset({
    required int assetId,
    required int restoredValue,
  }) async {
    await _client
        .from('asset_memos')
        .delete()
        .eq('asset_id', assetId)
        .eq('user_id', userId)
        .eq('is_income', true)
        .like('memo', '売却:%');

    await _client
        .from('assets')
        .update({'value': restoredValue, 'is_sold': false})
        .eq('id', assetId)
        .eq('user_id', userId);
  }

  /// 未確定時に使用。指定月スナップショットで is_sold=true だったアセットを
  /// assets テーブルに is_sold=true の状態で再登録する。
  Future<void> restoreSoldAssetsForMonth({
    required int year,
    required int month,
  }) async {
    final date = '$year-${month.toString().padLeft(2, '0')}-01';
    final soldRows = await _client
        .from('assets_history')
        .select()
        .eq('date', date)
        .eq('is_sold', true)
        .eq('user_id', userId);

    for (final row in soldRows as List<dynamic>) {
      final m = Map<String, dynamic>.from(row as Map);
      final assetId = (m['asset_id'] as num).toInt();

      final existing = await _client
          .from('assets')
          .select('id')
          .eq('id', assetId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        await _client.from('assets').insert({
          'id': assetId,
          'name': m['name'],
          'value': 0,
          'is_sold': true,
          'category1_id': m['category1_id'],
          'category2_id': m['category2_id'],
          'user_id': userId,
          'acquisition_price': m['acquisition_price'],
        });
      } else {
        await _client
            .from('assets')
            .update({'is_sold': true, 'value': 0})
            .eq('id', assetId)
            .eq('user_id', userId);
      }
    }
  }

  Future<void> deleteSoldCurrentAssets() async {
    await _client
        .from('assets')
        .delete()
        .eq('is_sold', true)
        .eq('user_id', userId);
  }

  /// 指定月のスナップショットに is_sold=true で記録されたアセットのみを assets テーブルから削除する。
  /// deleteSoldCurrentAssets() の代わりに使い、将来月の売却アセットを誤削除しないようにする。
  Future<void> deleteSoldAssetsForMonth({
    required int year,
    required int month,
  }) async {
    final date = '$year-${month.toString().padLeft(2, '0')}-01';
    final soldRows = await _client
        .from('assets_history')
        .select('asset_id')
        .eq('date', date)
        .eq('is_sold', true)
        .eq('user_id', userId);

    if (soldRows.isEmpty) return;

    final ids = (soldRows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['asset_id'] as int)
        .toList();

    // CASCADE DELETE 回避: 売却メモの asset_id を null に切り離してから assets を削除する。
    // asset_memos.asset_id が NOT NULL の場合は失敗するため、その際は DB マイグレーションが必要。
    try {
      await _client
          .from('asset_memos')
          .update({'asset_id': null})
          .inFilter('asset_id', ids)
          .eq('user_id', userId)
          .eq('is_income', true);
    } catch (_) {}

    await _client
        .from('assets')
        .delete()
        .inFilter('id', ids)
        .eq('user_id', userId);
  }

  /// 指定月リストの売却損益をカテゴリ込みで返す。
  /// 返り値: [{ 'year', 'month', 'category1_id', 'category1_name', 'profit' }, ...]
  Future<List<Map<String, dynamic>>> fetchMonthlySellProfits({
    required List<(int year, int month)> months,
  }) async {
    final uid = userId;
    final results = <Map<String, dynamic>>[];

    for (final (y, mo) in months) {
      final date = '$y-${mo.toString().padLeft(2, '0')}-01';
      final nextDt = DateTime(y, mo + 1);
      final nextDate =
          '${nextDt.year}-${nextDt.month.toString().padLeft(2, '0')}-01';

      final memos = await _client
          .from('asset_memos')
          .select('asset_id, memo, amount, direction')
          .eq('user_id', uid)
          .eq('is_income', true)
          .like('memo', '売却:%')
          .gte('memo_date', date)
          .lt('memo_date', nextDate);

      if ((memos as List).isEmpty) continue;

      // asset_id が残っているメモ（未確定月）とないメモ（確定済み月）に分離
      final memosWithId = <Map<String, dynamic>>[];
      final memosWithoutId = <Map<String, dynamic>>[];
      for (final m in memos) {
        final mm = Map<String, dynamic>.from(m as Map);
        (mm['asset_id'] != null ? memosWithId : memosWithoutId).add(mm);
      }

      // ① asset_id あり → assets テーブルから直接カテゴリ取得（未確定月用）
      final catById = <int, Map<String, dynamic>>{};
      if (memosWithId.isNotEmpty) {
        final ids = memosWithId.map((m) {
          final r = m['asset_id'];
          return r is int ? r : (r as num).toInt();
        }).toList();

        final assetRows = await _client
            .from('assets')
            .select('id, category1_id, categories1(name)')
            .inFilter('id', ids)
            .eq('user_id', uid);

        for (final a in assetRows as List<dynamic>) {
          final am = Map<String, dynamic>.from(a as Map);
          final id = am['id'] as int;
          final catId = am['category1_id'] as String?;
          final catName = (am['categories1'] as Map?)?['name'] as String?;
          catById[id] = {'category1_id': catId, 'category1_name': catName};
        }

        // assets テーブルにない（削除済み）場合は assets_history の最新レコードで補完
        final missing = ids.where((id) => !catById.containsKey(id)).toList();
        for (final aid in missing) {
          final rows = await _client
              .from('assets_history')
              .select('category1_id, category1_name')
              .eq('asset_id', aid)
              .eq('user_id', uid)
              .order('date', ascending: false)
              .limit(1);
          if ((rows as List).isNotEmpty) {
            final hm = Map<String, dynamic>.from(rows.first as Map);
            catById[aid] = {
              'category1_id': hm['category1_id'],
              'category1_name': hm['category1_name'],
            };
          }
        }
      }

      // ② asset_id なし → assets_history の is_sold=true レコードで名前照合（確定済み月用）
      final histByName = <String, Map<String, dynamic>>{};
      if (memosWithoutId.isNotEmpty) {
        final soldHistory = await _client
            .from('assets_history')
            .select('name, category1_id, category1_name')
            .eq('date', date)
            .eq('is_sold', true)
            .eq('user_id', uid);

        for (final h in soldHistory as List<dynamic>) {
          final hm = Map<String, dynamic>.from(h as Map);
          final name = hm['name'] as String?;
          if (name != null) histByName[name] = hm;
        }
      }

      for (final mm in [...memosWithId, ...memosWithoutId]) {
        final rawId = mm['asset_id'];
        final assetId = rawId == null
            ? null
            : (rawId is int ? rawId : (rawId as num).toInt());
        final amount = (mm['amount'] as num?)?.toInt() ?? 0;
        final dir = mm['direction'] as String?;
        final profit = dir == '出' ? -amount : amount;

        Map<String, dynamic>? catInfo;
        if (assetId != null) {
          catInfo = catById[assetId];
        }
        if (catInfo == null) {
          final memoText = mm['memo'] as String? ?? '';
          final name = memoText.startsWith('売却: ')
              ? memoText.substring(4)
              : memoText;
          catInfo = histByName[name];
        }

        results.add({
          'year': y,
          'month': mo,
          'category1_id': catInfo?['category1_id'] as String? ?? '__unknown__',
          'category1_name': catInfo?['category1_name'] as String? ?? 'その他',
          'profit': profit,
        });
      }
    }

    return results;
  }

  /// 指定月の assets_history と monthly_lock を削除し、前月末の状態をコピーして初期化する。
  /// [isCurrentMonth] が true のとき、assets テーブルも前月スナップショットの状態に復元する。
  Future<void> resetMonthData({
    required int year,
    required int month,
    bool isCurrentMonth = false,
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

    if (isCurrentMonth) {
      // ① assets テーブルを前月末の状態に復元（カテゴリ等）
      await _restoreCurrentAssetsFromPrevMonth(year: year, month: month);
      // ② 復元済みの assets テーブルからスナップショットを作り直す
      //    → アイコン含む正しいデータが assets_history に書き込まれる
      await upsertMonthlySnapshot(
        year: year,
        month: month,
        forceCurrentAssets: true,
      );
    } else {
      // 過去月: 前月スナップショットをコピーして復元
      final prevMonth = DateTime(year, month - 1);
      await copySnapshotToNextMonth(
        fromYear: prevMonth.year,
        fromMonth: prevMonth.month,
      );

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

  /// 前月スナップショットから assets テーブルを復元する。
  /// 削除済みアセットの再挿入・売却済みアセットの値戻し・当月売却メモの削除を行う。
  Future<void> _restoreCurrentAssetsFromPrevMonth({
    required int year,
    required int month,
  }) async {
    final prevMonth = DateTime(year, month - 1);
    final prevDate =
        '${prevMonth.year}-${prevMonth.month.toString().padLeft(2, '0')}-01';

    final prevSnapshot = await _client
        .from('assets_history')
        .select()
        .eq('date', prevDate)
        .eq('user_id', userId);

    for (final row in prevSnapshot as List<dynamic>) {
      final m = Map<String, dynamic>.from(row as Map);

      // 前月時点で既に売却済みのアセットは当月に復元しない
      if (m['is_sold'] == true) continue;

      final assetId = (m['asset_id'] as num).toInt();

      final existing = await _client
          .from('assets')
          .select('id')
          .eq('id', assetId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        // 売却・削除されたアセットを前月スナップショットの状態で再挿入
        await _client.from('assets').insert({
          'id': assetId,
          'name': m['name'],
          'value': m['value'],
          'is_sold': false,
          'category1_id': m['category1_id'],
          'category2_id': m['category2_id'],
          'user_id': userId,
          'acquisition_price': m['acquisition_price'],
          'icon_label': m['icon_label'],
          'icon_text_color': m['icon_text_color'],
          'icon_bg_color': m['icon_bg_color'],
        });
      } else {
        // 当月に変更されたアセットを前月スナップショットの状態に戻す
        // アイコンはスナップショットに保存されている場合のみ上書きする
        // （古いスナップショットはアイコンが null のため、null で上書きしない）
        final updates = <String, dynamic>{
          'value': m['value'],
          'is_sold': false,
          'name': m['name'],
          'category1_id': m['category1_id'],
          'category2_id': m['category2_id'],
          'acquisition_price': m['acquisition_price'],
        };
        if (m['icon_label'] != null) updates['icon_label'] = m['icon_label'];
        if (m['icon_text_color'] != null) updates['icon_text_color'] = m['icon_text_color'];
        if (m['icon_bg_color'] != null) updates['icon_bg_color'] = m['icon_bg_color'];

        await _client
            .from('assets')
            .update(updates)
            .eq('id', assetId)
            .eq('user_id', userId);
      }
    }

    // 当月の売却メモを削除
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final next = DateTime(year, month + 1);
    final to = '${next.year}-${next.month.toString().padLeft(2, '0')}-01';
    await _client
        .from('asset_memos')
        .delete()
        .eq('user_id', userId)
        .eq('is_income', true)
        .like('memo', '売却:%')
        .gte('memo_date', from)
        .lt('memo_date', to);
  }

  /// 指定月リスト（年度）の取得額合計・売却額合計を返す
  Future<({
    int acquisitionTotal,
    int sellTotal,
    int profitTotal,
    List<Map<String, dynamic>> profitByCategory,
  })> fetchFiscalYearTotals({
    required List<(int year, int month)> months,
  }) async {
    if (months.isEmpty) {
      return (acquisitionTotal: 0, sellTotal: 0, profitTotal: 0, profitByCategory: <Map<String, dynamic>>[]);
    }

    final sorted = [...months]..sort(
        (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    final first = sorted.first;
    final last = sorted.last;
    final now = DateTime.now();

    // ── 売却合計 ──────────────────────────────────────────
    final fromDate =
        '${first.$1}-${first.$2.toString().padLeft(2, '0')}-01';
    final nextOfLast = DateTime(last.$1, last.$2 + 1);
    final toDate =
        '${nextOfLast.year}-${nextOfLast.month.toString().padLeft(2, '0')}-01';

    final memos = await _client
        .from('asset_memos')
        .select('sell_price')
        .eq('user_id', userId)
        .eq('is_income', true)
        .like('memo', '売却:%')
        .gte('memo_date', fromDate)
        .lt('memo_date', toDate);

    int sellTotal = 0;
    for (final m in memos as List) {
      final price = (m as Map)['sell_price'];
      if (price != null) sellTotal += (price as num).toInt();
    }

    // ── 取得合計 ──────────────────────────────────────────
    // 年度開始月の前月スナップショットで「既存資産」を確定
    final prevFiscalDt = DateTime(first.$1, first.$2 - 1);
    final prevDate =
        '${prevFiscalDt.year}-${prevFiscalDt.month.toString().padLeft(2, '0')}-01';
    final preYearRows = await _client
        .from('assets_history')
        .select('asset_id')
        .eq('date', prevDate)
        .eq('user_id', userId);
    final preYearIds =
        (preYearRows as List).map((r) => ((r as Map)['asset_id'] as num).toInt()).toSet();

    final seenIds = <int>{};
    int acquisitionTotal = 0;

    // 過去月のスナップショットをまとめて取得
    final snapshotDates = sorted
        .where((m) => !(m.$1 == now.year && m.$2 == now.month))
        .map((m) => '${m.$1}-${m.$2.toString().padLeft(2, '0')}-01')
        .toList();
    if (snapshotDates.isNotEmpty) {
      final histRows = await _client
          .from('assets_history')
          .select('asset_id, acquisition_price, value')
          .inFilter('date', snapshotDates)
          .eq('user_id', userId);
      for (final row in histRows as List) {
        final m = Map<String, dynamic>.from(row as Map);
        final aid = (m['asset_id'] as num).toInt();
        if (!preYearIds.contains(aid) && seenIds.add(aid)) {
          final acq = m['acquisition_price'] ?? m['value'];
          if (acq != null) acquisitionTotal += (acq as num).toInt();
        }
      }
    }

    // 当月が年度内に含まれる場合は assets テーブルから補完
    if (sorted.any((m) => m.$1 == now.year && m.$2 == now.month)) {
      final currentRows = await _client
          .from('assets')
          .select('id, acquisition_price, value')
          .eq('user_id', userId);
      for (final row in currentRows as List) {
        final m = Map<String, dynamic>.from(row as Map);
        final aid = (m['id'] as num).toInt();
        if (!preYearIds.contains(aid) && seenIds.add(aid)) {
          final acq = m['acquisition_price'] ?? m['value'];
          if (acq != null) acquisitionTotal += (acq as num).toInt();
        }
      }
    }

    // ── 収益合計・カテゴリ別内訳 ─────────────────────────────
    final profitRows = await fetchMonthlySellProfits(months: months);
    final catMap = <String, ({String name, int profit})>{};
    for (final row in profitRows) {
      final id = row['category1_id'] as String;
      final name = row['category1_name'] as String;
      final profit = row['profit'] as int;
      catMap[id] = catMap.containsKey(id)
          ? (name: name, profit: catMap[id]!.profit + profit)
          : (name: name, profit: profit);
    }
    final profitByCategory = catMap.entries
        .map((e) => <String, dynamic>{
              'category1_id': e.key,
              'category1_name': e.value.name,
              'profit': e.value.profit,
            })
        .toList()
      ..sort((a, b) =>
          (b['profit'] as int).abs().compareTo((a['profit'] as int).abs()));
    final profitTotal =
        profitRows.fold(0, (sum, r) => sum + (r['profit'] as int));

    return (
      acquisitionTotal: acquisitionTotal,
      sellTotal: sellTotal,
      profitTotal: profitTotal,
      profitByCategory: profitByCategory,
    );
  }

  /// 指定月の売却額合計を返す（asset_memos.sell_price の合計）
  Future<int> fetchMonthlySellTotal({
    required int year,
    required int month,
  }) async {
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final next = DateTime(year, month + 1);
    final to = '${next.year}-${next.month.toString().padLeft(2, '0')}-01';
    final rows = await _client
        .from('asset_memos')
        .select('sell_price')
        .eq('user_id', userId)
        .eq('is_income', true)
        .like('memo', '売却:%')
        .gte('memo_date', from)
        .lt('memo_date', to);
    int total = 0;
    for (final row in rows as List) {
      final price = (row as Map)['sell_price'];
      if (price is int) total += price;
      if (price is double) total += price.toInt();
    }
    return total;
  }

  // ── 不動産 ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchRealEstateDetails(int assetId) async {
    final rows = await _client
        .from('real_estate_details')
        .select()
        .eq('asset_id', assetId)
        .eq('user_id', userId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first as Map);
  }

  Future<void> insertRealEstateAsset({
    required String name,
    required String? category1Id,
    required String? category2Id,
    required int estimatedValue,
    required int purchasePrice,
    required int downPayment,
    required String acquisitionDate,
    required int originalLoanAmount,
    required String loanStartDate,
    required int loanTermMonths,
    required double interestRatePercent,
    required int monthlyPayment,
    required int currentLoanBalance,
    required int managementFee,
    required int repairReserveFund,
    required int propertyTaxMonthly,
    required int otherMonthlyCosts,
    required int virtualMonthlyRent,
  }) async {
    final netEquity = estimatedValue - currentLoanBalance;
    final result = await _client
        .from('assets')
        .insert({
          'name': name,
          'value': netEquity < 0 ? 0 : netEquity,
          'category1_id': category1Id,
          'category2_id': category2Id,
          'acquisition_price': purchasePrice,
          'user_id': userId,
        })
        .select('id')
        .single();

    final assetId = result['id'] as int;
    await _client.from('real_estate_details').insert({
      'asset_id': assetId,
      'user_id': userId,
      'purchase_price': purchasePrice,
      'down_payment': downPayment,
      'acquisition_date': acquisitionDate,
      'original_loan_amount': originalLoanAmount,
      'loan_start_date': loanStartDate,
      'loan_term_months': loanTermMonths,
      'interest_rate_percent': interestRatePercent,
      'monthly_payment': monthlyPayment,
      'current_loan_balance': currentLoanBalance,
      'management_fee': managementFee,
      'repair_reserve_fund': repairReserveFund,
      'property_tax_monthly': propertyTaxMonthly,
      'other_monthly_costs': otherMonthlyCosts,
      'virtual_monthly_rent': virtualMonthlyRent,
      'estimated_value': estimatedValue,
    });
  }

  Future<void> updateRealEstateDetails({
    required int assetId,
    required int estimatedValue,
    required int currentLoanBalance,
    required double interestRatePercent,
    required int monthlyPayment,
    required int managementFee,
    required int repairReserveFund,
    required int propertyTaxMonthly,
    required int otherMonthlyCosts,
    required int virtualMonthlyRent,
  }) async {
    final netEquity = estimatedValue - currentLoanBalance;
    await Future.wait([
      _client.from('real_estate_details').update({
        'estimated_value': estimatedValue,
        'current_loan_balance': currentLoanBalance,
        'interest_rate_percent': interestRatePercent,
        'monthly_payment': monthlyPayment,
        'management_fee': managementFee,
        'repair_reserve_fund': repairReserveFund,
        'property_tax_monthly': propertyTaxMonthly,
        'other_monthly_costs': otherMonthlyCosts,
        'virtual_monthly_rent': virtualMonthlyRent,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('asset_id', assetId).eq('user_id', userId),
      _client.from('assets').update({
        'value': netEquity < 0 ? 0 : netEquity,
      }).eq('id', assetId).eq('user_id', userId),
    ]);
  }

  // ── バックアップ ──────────────────────────────────────────────────────────

  /// バックアップ復元専用: ユーザーの全データを FK 安全な順序で削除する
  Future<void> deleteAllUserData() async {
    final uid = userId;
    await Future.wait([
      _client.from('asset_memos').delete().eq('user_id', uid),
      _client.from('assets_history').delete().eq('user_id', uid),
      _client.from('monthly_lock').delete().eq('user_id', uid),
    ]);
    await _client.from('assets').delete().eq('user_id', uid);
    await _client.from('categories2').delete().eq('user_id', uid);
    await _client.from('categories1').delete().eq('user_id', uid);
  }
}
