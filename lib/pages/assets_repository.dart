import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/user_id.dart';

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
        .select();

    if (updated.isEmpty) {
      await _client.from('monthly_lock').insert({
        'year': year,
        'month': month,
        'confirmed': confirmed,
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
        .eq('month', month);
  }

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

  Future<List<Map<String, dynamic>>> fetchHistoryByDate(
    String snapshotDate,
  ) async {
    final data = await _client
        .from('assets_history')
        .select(
          'id, asset_id, name, value, category1, category2, category3, date',
        )
        .eq('date', snapshotDate);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> deleteCurrentAsset(int id) {
    return _client.from('assets').delete().eq('id', id);
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
        .eq('date', date);
    if (data.isEmpty) return null;
    return data.first['value'] as int?;
  }

  Future<List<Map<String, dynamic>>> fetchStartOfYearHistory({
    required int year,
  }) async {
    final date = '$year-01-01';
    final data = await _client.from('assets_history').select().eq('date', date);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> fetchPreviousMonthHistory({
    required int year,
    required int month,
  }) async {
    // 前月の年と月を計算
    final previous = DateTime(year, month - 1);
    final previousYear = previous.year;
    final previousMonth = previous.month;

    // 前月の月初日を取得（スナップショットは月初に保存されるため）
    final date = '$previousYear-${previousMonth.toString().padLeft(2, '0')}-01';
    final data = await _client.from('assets_history').select().eq('date', date);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> upsertMonthlySnapshot({
    required int year,
    required int month,
  }) async {
    final allAssets = await _client.from('assets').select();
    final snapshotDate = '$year-${month.toString().padLeft(2, '0')}-01';

    for (final a in allAssets) {
      final existing = await _client
          .from('assets_history')
          .select()
          .eq('asset_id', a['id'])
          .eq('date', snapshotDate);

      if (existing.isEmpty) {
        await _client.from('assets_history').insert({
          'asset_id': a['id'],
          'name': a['name'],
          'category1': a['category1'],
          'category2': a['category2'],
          'category3': a['category3'],
          'value': a['value'],
          'date': snapshotDate,
        });
      } else {
        await _client
            .from('assets_history')
            .update({
              'name': a['name'],
              'category1': a['category1'],
              'category2': a['category2'],
              'category3': a['category3'],
              'value': a['value'],
            })
            .eq('asset_id', a['id'])
            .eq('date', snapshotDate);
      }
    }
  }
}
