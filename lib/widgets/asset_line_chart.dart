import 'package:asset_note/theme/app_tokens.dart';
import 'package:asset_note/utils/yen_format.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// 総資産の推移ミニグラフ
///
/// - Y 軸は目盛り 3 本程度に収まるキリの良い間隔（100万・200万・500万…）
/// - 単位は日本語表記（2,400万 / 1.2億）
/// - 一番下の Y ラベルは X 軸ラベルと重なるため表示しない
class AssetLineChart extends StatelessWidget {
  final List<double> points;
  final List<String> labels;
  final double height;

  const AssetLineChart({
    super.key,
    required this.points,
    required this.labels,
    this.height = 30,
  });

  static const double _leftReserved = 44;
  static const double _bottomReserved = 20;
  static const double _maxTicks = 3;
  static const List<double> _niceStepsInMan = [
    1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000,
  ];

  @override
  Widget build(BuildContext context) {
    if (points.length < 2 || labels.length < 2) {
      return const SizedBox(
        height: 40,
        child: Center(child: Text('データが不足しています')),
      );
    }

    if (labels.length != points.length) {
      return const SizedBox(
        height: 40,
        child: Center(child: Text('ラベル数が不正です')),
      );
    }

    final colors = context.colors;
    final accent = colors.accent;

    final rawMin = points.reduce((a, b) => a < b ? a : b);
    final rawMax = points.reduce((a, b) => a > b ? a : b);

    final step = _niceStep(rawMax - rawMin);
    final minY = (rawMin / step).floorToDouble() * step;
    var maxY = (rawMax / step).ceilToDouble() * step;
    if (maxY <= minY) maxY = minY + step;

    final axisStyle = TextStyle(
      fontSize: AppFont.caption2,
      color: colors.secondaryLabel,
      fontFeatures: AppFont.tabular,
    );

    // 月ラベルが多いときは間引く（最後の月は常に表示）
    final labelEvery = labels.length > 7 ? 2 : 1;

    final spots = [
      for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i]),
    ];

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        children: [
          LineChart(
            LineChartData(
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: step,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: colors.separator, strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: _leftReserved,
                    interval: step,
                    getTitlesWidget: (value, meta) {
                      // 最下段は X 軸ラベルとぶつかるので出さない
                      if (value <= minY || value > maxY) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: Text(
                          formatYenShort(value),
                          style: axisStyle,
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: _bottomReserved,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value % 1 != 0) return const SizedBox.shrink();
                      final index = value.toInt();
                      if (index < 0 || index >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      final isLast = index == labels.length - 1;
                      final fromEnd = labels.length - 1 - index;
                      if (!isLast && fromEnd % labelEvery != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(labels[index], style: axisStyle),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  barWidth: 2,
                  color: accent,
                  // 最新月だけ点を打つ（値は総資産として上に表示済み）
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, _) => spot.x == points.length - 1,
                    getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                      radius: 3.5,
                      color: accent,
                      strokeWidth: 2,
                      strokeColor: colors.surface,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accent.withValues(alpha: 0.30),
                        accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 目盛りが [_maxTicks] 本程度に収まる、キリの良い間隔（円）
  double _niceStep(double range) {
    final rangeMan = range / 10000;
    for (final s in _niceStepsInMan) {
      if (rangeMan / s <= _maxTicks) return s * 10000;
    }
    return _niceStepsInMan.last * 10000;
  }

}
