import 'package:intl/intl.dart';

final _yen = NumberFormat('#,##0', 'ja_JP');

/// 金額を `¥1,234` / `-¥1,234` 形式で返す。
///
/// [signed] が true のときは増減表示として `+¥1,234` のように + も付ける。
/// 0 は符号なし `¥0`。
String formatYen(num value, {bool signed = false}) {
  final abs = _yen.format(value.abs().round());
  if (value < 0) return '-¥$abs';
  if (signed && value > 0) return '+¥$abs';
  return '¥$abs';
}

/// グラフ軸などの短い表記：`2,430万` / `1.2億`
String formatYenShort(num value) {
  final v = value.toDouble();
  if (v.abs() >= 100000000) {
    final oku = v / 100000000;
    return '${oku.toStringAsFixed(oku.abs() >= 10 ? 0 : 1)}億';
  }
  if (v.abs() >= 10000) {
    return '${_yen.format((v / 10000).round())}万';
  }
  return _yen.format(v.round());
}
