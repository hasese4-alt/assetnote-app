import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:asset_note/utils/user_id.dart';

class AssetsRepository {
  AssetsRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchMonthlyLock({
    required int year,
    required int month,
  }) {
    return _client
        .from('monthly_lock')
        .select()
        .eq('year', year)
        .eq('month', month)
        .eq('user_id', userId)
        .maybeSingle();
  }

  Future<void> upsertMonthlyLock({
    required int year,
    required int month,
    required bool confirmed,
  }) async {
    final updated = await _client
        .from('monthly_lock')
        .update({'confirmed': confirmed})
        .eq('year', year)
        .eq('month', month)
        .eq('user_id', userId)
        .select();

    if (updated.isEmpty) {
      await _client.from('monthly_lock').insert({
        'year': year,
        'month': month,
        'confirmed': confirmed,
        'user_id': userId,
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

  // ★ 月次スナップショット（ID + name を保存するよう修正）
  Future<void> upsertMonthlySnapshot({
    required int year,
    required int month,
  }) async {
    final allAssets = await _client
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

    final snapshotDate = '$year-${month.toString().padLeft(2, '0')}-01';

    for (final a in allAssets) {
      final existing = await _client
          .from('assets_history')
          .select()
          .eq('asset_id', a['id'])
          .eq('date', snapshotDate)
          .eq('user_id', userId);

      final record = {
        'asset_id': a['id'],
        'name': a['name'],
        'value': a['value'],
        'category1_id': a['category1_id'],
        'category2_id': a['category2_id'],
        'category1_name': a['categories1']?['name'],
        'category2_name': a['categories2']?['name'],
        'date': snapshotDate,
        'user_id': userId,
      };

      if (existing.isEmpty) {
        await _client.from('assets_history').insert(record);
      } else {
        await _client
            .from('assets_history')
            .update(record)
            .eq('asset_id', a['id'])
            .eq('date', snapshotDate)
            .eq('user_id', userId);
      }
    }
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
}
