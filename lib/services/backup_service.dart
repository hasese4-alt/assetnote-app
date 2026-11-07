import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:asset_note/utils/user_id.dart';

class BackupValidationException implements Exception {
  BackupValidationException(this.message);
  final String message;
  @override
  String toString() => 'BackupValidationException: $message';
}

class BackupService {
  BackupService(this._client);

  final SupabaseClient _client;

  // ───────────────────────── BACKUP ─────────────────────────

  Future<void> runBackup() async {
    final uid = userId;
    final data = await _fetchAllData(uid);

    final json = jsonEncode({
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'user_id': uid,
      ...data,
    });

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/assetsnote_backup_$dateStr.json');
    await file.writeAsString(json, encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      text: 'AssetNote バックアップ',
    );
  }

  Future<Map<String, dynamic>> _fetchAllData(String uid) async {
    // Supabase のデフォルト上限（通常 1000 行）を超えないよう明示的に高い limit を指定する。
    final results = await Future.wait([
      _client.from('categories1').select().eq('user_id', uid).limit(10000),
      _client.from('categories2').select().eq('user_id', uid).limit(10000),
      _client.from('assets').select().eq('user_id', uid).limit(10000),
      _client.from('assets_history').select().eq('user_id', uid).limit(500000),
      _client.from('asset_memos').select().eq('user_id', uid).limit(500000),
      _client.from('monthly_lock').select().eq('user_id', uid).limit(10000),
    ]);

    return {
      'categories1': results[0],
      'categories2': results[1],
      'assets': results[2],
      'assets_history': results[3],
      'asset_memos': results[4],
      'monthly_lock': results[5],
    };
  }

  // ───────────────────────── VALIDATE ─────────────────────────

  Map<String, dynamic> validateBackupJson(String content) {
    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      throw BackupValidationException('JSONのパースに失敗しました');
    }

    if (decoded is! Map<String, dynamic>) {
      throw BackupValidationException('無効なファイル形式です');
    }

    if (decoded['version'] != 1) {
      throw BackupValidationException(
          '非対応のバックアップバージョンです (version: ${decoded['version']})');
    }

    const requiredKeys = [
      'categories1',
      'categories2',
      'assets',
      'assets_history',
      'asset_memos',
      'monthly_lock',
    ];
    for (final key in requiredKeys) {
      if (decoded[key] is! List) {
        throw BackupValidationException('データが不完全です (missing: $key)');
      }
    }

    return decoded;
  }

  // ───────────────────────── RESTORE ─────────────────────────

  Future<void> runRestore(String jsonContent) async {
    final raw = validateBackupJson(jsonContent);
    final uid = userId;

    // Phase 1: 削除（FK 安全な逆順）
    await Future.wait([
      _client.from('asset_memos').delete().eq('user_id', uid),
      _client.from('assets_history').delete().eq('user_id', uid),
      _client.from('monthly_lock').delete().eq('user_id', uid),
    ]);
    await _client.from('assets').delete().eq('user_id', uid);
    await _client.from('categories2').delete().eq('user_id', uid);
    await _client.from('categories1').delete().eq('user_id', uid);

    // Phase 2: categories1（UUID PK → 同一 ID で挿入）
    final cats1 = raw['categories1'] as List<dynamic>;
    if (cats1.isNotEmpty) {
      final rows = cats1
          .map((r) => {
                'id': r['id'],
                'user_id': uid,
                'name': r['name'],
                'icon': r['icon'],
              })
          .toList();
      await _client.from('categories1').insert(rows);
    }

    // Phase 3: categories2（UUID PK → 同一 ID で挿入）
    final cats2 = raw['categories2'] as List<dynamic>;
    if (cats2.isNotEmpty) {
      final rows = cats2
          .map((r) => {
                'id': r['id'],
                'user_id': uid,
                'parent_id': r['parent_id'],
                'name': r['name'],
                'hide_favicon': r['hide_favicon'],
              })
          .toList();
      await _client.from('categories2').insert(rows);
    }

    // Phase 4: assets（int PK → ID を記録して assetIdMap を構築）
    final assetIdMap = <int, int>{};
    final assetRows = raw['assets'] as List<dynamic>;
    for (final r in assetRows) {
      final oldId = r['id'] as int;
      final result = await _client
          .from('assets')
          .insert({
            'user_id': uid,
            'name': r['name'],
            'value': r['value'],
            'is_sold': r['is_sold'],
            'acquisition_price': r['acquisition_price'],
            'category1_id': r['category1_id'],
            'category2_id': r['category2_id'],
            'icon_label': r['icon_label'],
            'icon_text_color': r['icon_text_color'],
            'icon_bg_color': r['icon_bg_color'],
            'hide_favicon': r['hide_favicon'],
          })
          .select('id')
          .single();
      assetIdMap[oldId] = result['id'] as int;
    }

    // Phase 5: assets_history（asset_id をリマップ、バッチ insert）
    // assetIdMap に存在しない asset_id（バックアップ前に削除されたアセット）は
    // スキップする。null のまま insert すると NOT NULL 制約違反でバッチ全体が失敗するため。
    final histRows = raw['assets_history'] as List<dynamic>;
    if (histRows.isNotEmpty) {
      final rows = histRows
          .where((r) {
            final oldId = r['asset_id'];
            if (oldId == null) return false;
            return assetIdMap.containsKey(oldId as int);
          })
          .map((r) => {
                'user_id': uid,
                'asset_id': assetIdMap[r['asset_id'] as int],
                'date': r['date'],
                'name': r['name'],
                'value': r['value'],
                'is_sold': r['is_sold'],
                'acquisition_price': r['acquisition_price'],
                'category1_id': r['category1_id'],
                'category2_id': r['category2_id'],
                'category1_name': r['category1_name'],
                'category2_name': r['category2_name'],
                'icon_label': r['icon_label'],
                'icon_text_color': r['icon_text_color'],
                'icon_bg_color': r['icon_bg_color'],
              })
          .toList();

      // ペイロードサイズ超過を防ぐため 500 行ずつ分割 insert する
      const chunkSize = 500;
      for (var i = 0; i < rows.length; i += chunkSize) {
        final chunk = rows.sublist(i, min(i + chunkSize, rows.length));
        await _client.from('assets_history').insert(chunk);
      }
    }

    // Phase 6: monthly_lock（FK なし、バッチ insert）
    final lockRows = raw['monthly_lock'] as List<dynamic>;
    if (lockRows.isNotEmpty) {
      final rows = lockRows
          .map((r) => {
                'user_id': uid,
                'year': r['year'],
                'month': r['month'],
                'confirmed': r['confirmed'],
              })
          .toList();
      await _client.from('monthly_lock').insert(rows);
    }

    // Phase 7: asset_memos（paired_memo_id は null で挿入、memoIdMap を構築）
    final memoIdMap = <int, int>{};
    final memoRows = raw['asset_memos'] as List<dynamic>;
    for (final r in memoRows) {
      final oldId = r['id'] as int;
      final oldAssetId = r['asset_id'] as int?;
      final oldLinkedId = r['linked_asset_id'] as int?;
      final result = await _client
          .from('asset_memos')
          .insert({
            'user_id': uid,
            'asset_id':
                oldAssetId != null ? assetIdMap[oldAssetId] : null,
            'memo_date': r['memo_date'],
            'memo': r['memo'],
            'amount': r['amount'],
            'direction': r['direction'],
            'is_income': r['is_income'],
            'sell_price': r['sell_price'],
            'linked_asset_id':
                oldLinkedId != null ? assetIdMap[oldLinkedId] : null,
            'paired_memo_id': null,
            'is_auto': r['is_auto'],
          })
          .select('id')
          .single();
      memoIdMap[oldId] = result['id'] as int;
    }

    // Phase 8: paired_memo_id を UPDATE（自己参照 FK の 2 パス目）
    for (final r in memoRows) {
      final oldPairedId = r['paired_memo_id'] as int?;
      if (oldPairedId == null) continue;

      final newId = memoIdMap[r['id'] as int];
      final newPairedId = memoIdMap[oldPairedId];
      if (newId == null || newPairedId == null) continue;

      await _client
          .from('asset_memos')
          .update({'paired_memo_id': newPairedId})
          .eq('id', newId)
          .eq('user_id', uid);
    }
  }
}
