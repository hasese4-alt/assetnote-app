class AssetsViewModel {
  /// Thresholds in same currency unit as [total] (rough “wealth ladder” for UI).
  static const Map<String, List<int>> defaultWealthThresholdsByAge = {
    '30s': [100, 300, 600, 1000, 1500, 2500],
  };

  /// Returns a 0–1 “upper tail” style fraction for the percentile label (not statistical).
  static double wealthPercentileForTotal(
    int total, {
    String ageGroup = '30s',
    Map<String, List<int>>? thresholdsByAge,
  }) {
    final dist =
        (thresholdsByAge ?? defaultWealthThresholdsByAge)[ageGroup] ?? const [];
    if (dist.length < 5) return 0;

    if (total < dist[0]) return 0.50;
    if (total < dist[1]) return 0.30;
    if (total < dist[2]) return 0.20;
    if (total < dist[3]) return 0.10;
    if (total < dist[4]) return 0.05;
    return 0.03;
  }

  static int _valueAsInt(Map<String, dynamic> a) {
    final v = a['value'];
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return 0;
  }

  static int _compareAssetValueDesc(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    return _valueAsInt(b).compareTo(_valueAsInt(a));
  }

  /// Groups assets for the list UI. Order: category1 by total (desc), then
  /// category2 by total (desc), then assets in each grid by value (desc).

  static Map<String, Map<String, List<Map<String, dynamic>>>> groupForDisplay(
    List<Map<String, dynamic>> assets,
  ) {
    final grouped = <String, Map<String, List<Map<String, dynamic>>>>{};

    for (final a in assets) {
      final c1Id = a['category1_id'] ?? 'uncategorized';
      final c2Id = a['category2_id'] ?? '_';

      grouped.putIfAbsent(c1Id, () => <String, List<Map<String, dynamic>>>{});
      grouped[c1Id]!.putIfAbsent(c2Id, () => <Map<String, dynamic>>[]);
      grouped[c1Id]![c2Id]!.add(a);
    }

    // ソートはそのまま
    for (final midMap in grouped.values) {
      for (final list in midMap.values) {
        list.sort(_compareAssetValueDesc);
      }
    }

    // 第一分類の並び替え
    final c1Keys = grouped.keys.toList()
      ..sort(
        (a, b) =>
            categoryTotal(grouped[b]!).compareTo(categoryTotal(grouped[a]!)),
      );

    final ordered = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final c1Id in c1Keys) {
      final midMap = grouped[c1Id]!;
      final c2Keys = midMap.keys.toList()
        ..sort(
          (a, b) => secondCategoryTotal(
            midMap[b]!,
          ).compareTo(secondCategoryTotal(midMap[a]!)),
        );

      final orderedMid = <String, List<Map<String, dynamic>>>{};
      for (final c2Id in c2Keys) {
        orderedMid[c2Id] = midMap[c2Id]!;
      }

      ordered[c1Id] = orderedMid;
    }

    return ordered;
  }

  static int total(List<Map<String, dynamic>> assets) {
    return assets.fold<int>(0, (sum, a) => sum + _valueAsInt(a));
  }

  static int categoryTotal(
    Map<String, List<Map<String, dynamic>>> secondGroups,
  ) {
    var total = 0;
    for (final mid in secondGroups.values) {
      for (final a in mid) {
        total += _valueAsInt(a);
      }
    }
    return total;
  }

  static int secondCategoryTotal(List<Map<String, dynamic>> assets) {
    var total = 0;
    for (final a in assets) {
      total += _valueAsInt(a);
    }
    return total;
  }
}
