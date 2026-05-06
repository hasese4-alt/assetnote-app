import '../services/assets_repository.dart';

class AssetsViewModel {
  final AssetsRepository repo;

  AssetsViewModel(this.repo);

  /// Thresholds in yen. Based on Japan household asset distribution statistics.
  /// [50th, 30th, 20th, 10th, 5th, 3rd] percentile boundaries.
  static const Map<String, List<int>> defaultWealthThresholdsByAge = {
    '20s': [300_000, 1_000_000, 2_000_000, 5_000_000, 10_000_000, 20_000_000],
    '30s': [1_000_000, 3_000_000, 6_000_000, 10_000_000, 15_000_000, 30_000_000],
    '40s': [2_000_000, 5_000_000, 10_000_000, 17_000_000, 25_000_000, 50_000_000],
    '50s': [3_000_000, 7_000_000, 13_000_000, 20_000_000, 35_000_000, 70_000_000],
    '60s': [5_000_000, 10_000_000, 20_000_000, 30_000_000, 50_000_000, 100_000_000],
  };

  static String ageGroupForAge(int age) {
    if (age < 30) return '20s';
    if (age < 40) return '30s';
    if (age < 50) return '40s';
    if (age < 60) return '50s';
    return '60s';
  }

  static String ageGroupJapaneseLabel(String group) {
    switch (group) {
      case '20s': return '20代';
      case '30s': return '30代';
      case '40s': return '40代';
      case '50s': return '50代';
      case '60s': return '60代以上';
      default: return group;
    }
  }

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

    for (final midMap in grouped.values) {
      for (final list in midMap.values) {
        list.sort(_compareAssetValueDesc);
      }
    }

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

Future<List<Map<String, dynamic>>> fetchGraphHistory() async {
  final now = DateTime.now();
  final startOfYear = DateTime(now.year, 1, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0);

  // ① 生データ取得
  final raw = await repo.fetchHistoryRaw(from: startOfYear, to: endOfMonth);

  // ② 日付を year / month に正規化
  final normalized = raw.map((h) {
    final rawDate = h['date'];
    DateTime? dt;

    if (rawDate is String) dt = DateTime.tryParse(rawDate);
    if (rawDate is DateTime) dt = rawDate;

    return {
      ...h,
      'year': dt?.year,
      'month': dt?.month,
    };
  }).toList();

  // ③ 月ごとに合算（キーは "2026-01" のように固定）
  final monthly = <String, Map<String, dynamic>>{};

  for (final h in normalized) {
    final y = h['year'] as int?;
    final m = h['month'] as int?;
    final v = (h['value'] as num?)?.toInt() ?? 0;

    if (y == null || m == null) continue;

    final key = "$y-${m.toString().padLeft(2, '0')}";

    monthly[key] ??= {'year': y, 'month': m, 'total': 0};
    monthly[key]!['total'] = (monthly[key]!['total'] as int) + v;
  }

  // ④ リスト化して月順にソート
  final monthlyList = monthly.values.toList()
    ..sort((a, b) {
      final ay = a['year'] as int;
      final by = b['year'] as int;
      final am = a['month'] as int;
      final bm = b['month'] as int;
      return ay != by ? ay.compareTo(by) : am.compareTo(bm);
    });

  return monthlyList;
}

}
