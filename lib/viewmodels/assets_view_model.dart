class AssetsViewModel {
  static int _compareAssetValueDesc(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    return ((b['value'] as int?) ?? 0).compareTo((a['value'] as int?) ?? 0);
  }

  /// Groups assets for the list UI. Order: category1 by total (desc), then
  /// category2 by total (desc), then assets in each grid by value (desc).

  static Map<String, Map<String, List<Map<String, dynamic>>>> groupForDisplay(
    List<Map<String, dynamic>> assets,
  ) {
    final grouped = <String, Map<String, List<Map<String, dynamic>>>>{};

    for (final a in assets) {
      // ★ ID ベースに変更
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
    return assets.fold<int>(0, (sum, a) => sum + ((a['value'] as int?) ?? 0));
  }

  static int categoryTotal(
    Map<String, List<Map<String, dynamic>>> secondGroups,
  ) {
    var total = 0;
    for (final mid in secondGroups.values) {
      for (final a in mid) {
        total += (a['value'] as int?) ?? 0;
      }
    }
    return total;
  }

  static int secondCategoryTotal(List<Map<String, dynamic>> assets) {
    var total = 0;
    for (final a in assets) {
      total += (a['value'] as int?) ?? 0;
    }
    return total;
  }
}
