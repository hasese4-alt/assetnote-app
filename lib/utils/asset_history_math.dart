/// Pure helpers for history snapshots and category totals on the assets list.
abstract final class AssetHistoryMath {
  static int? coerceInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  /// asset_id → Jan 1 snapshot value (one batch, no per-card API).
  static Map<int, int> startValuesByAssetId(
    List<Map<String, dynamic>> history,
  ) {
    final m = <int, int>{};
    for (final h in history) {
      final aid = coerceInt(h['asset_id']);
      if (aid == null) continue;
      m[aid] = coerceInt(h['value']) ?? 0;
    }
    return m;
  }

  static int startTotalForAssets(
    List<Map<String, dynamic>> items,
    Map<int, int> startByAssetId,
  ) {
    var t = 0;
    for (final a in items) {
      final aid = coerceInt(a['asset_id']) ?? coerceInt(a['id']);
      if (aid != null) t += startByAssetId[aid] ?? 0;
    }
    return t;
  }

  static int sumHistoryValues(List<Map<String, dynamic>> history) {
    var total = 0;
    for (final h in history) {
      total += h['value'] as int? ?? 0;
    }
    return total;
  }
}
