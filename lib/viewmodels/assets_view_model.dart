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
      final c1 = (a['category1'] as String?) ?? 'Uncategorized';
      final c2 = (a['category2'] as String?) ?? '';
      final useC2 = c2.isNotEmpty &&
          c2 != 'その他' &&
          c2 != 'Other' &&
          c1 != c2;

      grouped.putIfAbsent(c1, () => <String, List<Map<String, dynamic>>>{});
      final key = useC2 ? c2 : '_';
      grouped[c1]!.putIfAbsent(key, () => <Map<String, dynamic>>[]);
      grouped[c1]![key]!.add(a);
    }

    for (final midMap in grouped.values) {
      for (final list in midMap.values) {
        list.sort(_compareAssetValueDesc);
      }
    }

    final c1Keys = grouped.keys.toList()
      ..sort(
        (a, b) => categoryTotal(grouped[b]!).compareTo(categoryTotal(grouped[a]!)),
      );

    final ordered = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final c1 in c1Keys) {
      final midMap = grouped[c1]!;
      final c2Keys = midMap.keys.toList()
        ..sort(
          (a, b) => secondCategoryTotal(midMap[b]!)
              .compareTo(secondCategoryTotal(midMap[a]!)),
        );
      final orderedMid = <String, List<Map<String, dynamic>>>{};
      for (final c2 in c2Keys) {
        orderedMid[c2] = midMap[c2]!;
      }
      ordered[c1] = orderedMid;
    }

    return ordered;
  }

  static int total(List<Map<String, dynamic>> assets) {
    return assets.fold<int>(0, (sum, a) => sum + ((a['value'] as int?) ?? 0));
  }

  static int categoryTotal(Map<String, List<Map<String, dynamic>>> secondGroups) {
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
