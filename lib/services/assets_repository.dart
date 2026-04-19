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
        category1_id,
        category2_id,
        categories1(name),
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

  /// Writes one [assets_history] row per current asset for the month snapshot date.
  Future<void> upsertMonthlySnapshot({
    required int year,
    required int month,
  }) async {
    final snapshotDate = '$year-${month.toString().padLeft(2, '0')}-01';

    // ① その月の履歴があるか確認
    final existingHistory = await _client
        .from('assets_history')
        .select()
        .eq('date', snapshotDate)
        .eq('user_id', userId);

    List<Map<String, dynamic>> sourceAssets;

    if (existingHistory.isNotEmpty) {
      // ② 履歴あり → その月の資産を使う
      sourceAssets = List<Map<String, dynamic>>.from(existingHistory);
    } else {
      // ③ 履歴なし → 初回確定なので現在の資産を使う
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
        .select('id, name')
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
  }) async {
    await _client.from('assets').insert({
      'name': name,
      'value': value,
      'category1_id': category1Id,
      'category2_id': category2Id,
      'user_id': userId,
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
  }) async {
    final result = await _client
        .from('assets')
        .insert({
          'name': name,
          'value': value,
          'category1_id': category1Id,
          'category2_id': category2Id,
          'user_id': userId,
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
    });
  }

  Future<void> updateAsset({
    required int id,
    required String name,
    required int value,
    required String? category1Id,
    required String? category2Id,
  }) async {
    await _client
        .from('assets')
        .update({
          'name': name,
          'value': value,
          'category1_id': category1Id,
          'category2_id': category2Id,
        })
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<void> updateAssetsHistoryRow({
    required int id,
    required String name,
    required int value,
  }) async {
    await _client
        .from('assets_history')
        .update({'name': name, 'value': value})
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<void> insertCategory1({required String name}) async {
    await _client.from('categories1').insert({'user_id': userId, 'name': name});
  }

  Future<void> updateCategory1({required String id, required String name}) async {
    await _client.from('categories1').update({'name': name}).eq('id', id);
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
}
