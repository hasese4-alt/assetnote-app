import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AssetLineChart extends StatelessWidget {
  final List<double> points;
  final List<String> labels;

  const AssetLineChart({
    super.key,
    required this.points,
    required this.labels,
  });

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

    // 元の min/max
    double minY = points.reduce((a, b) => a < b ? a : b);
    double maxY = points.reduce((a, b) => a > b ? a : b);

    // === Y軸を100万単位で丸める（そのまま） ===
    final minYRounded = _roundDownToOneMillion(minY);
    final maxYRounded = _roundUpToOneMillion(maxY);

    // ★ ミニグラフ用：高さを 30 に固定
    const double chartHeight = 30;

    final spots = [
      for (int i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i]),
    ];

    final latestValue = points.last;

    return SizedBox(
      height: chartHeight,
      child: Stack(
        children: [
          LineChart(
            LineChartData(
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              minY: minYRounded,
              maxY: maxYRounded,

              // ★ ミニグラフ用：線をさらに薄く
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1000000,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 0.5, // ← 薄く
                  );
                },
              ),

              borderData: FlBorderData(show: false),

              titlesData: FlTitlesData(
                // ★ ミニグラフ用：Y軸ラベルを小さく
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26, // ← 小さく
                    interval: 1000000,
                    getTitlesWidget: (value, meta) {
                      if (value < minYRounded || value > maxYRounded) {
                        return const SizedBox.shrink();
                      }
                      final million = (value / 1000000).round();
                      return Text(
                        "${million}M",
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(fontSize: 9), // ← 小さく
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

                // ★ ミニグラフ用：X軸も小さく
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 14,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value % 1 != 0) return const SizedBox.shrink();
                      final index = value.toInt();
                      if (index < 0 || index >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        labels[index],
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(fontSize: 9),
                      );
                    },
                  ),
                ),
              ),

              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  barWidth: 2, // ← 細く
                  color: Theme.of(context).colorScheme.primary,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.10),
                  ),
                ),
              ],
            ),
          ),

          // ★ ミニグラフ用：現在値ラベルの位置計算を調整
          Positioned(
            right: 0,
            top: _calcTopPosition(latestValue, minYRounded, maxYRounded, chartHeight),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${(latestValue / 1000000).toStringAsFixed(1)}M",
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _roundDownToOneMillion(double value) {
    const unit = 1000000;
    return (value ~/ unit) * unit.toDouble();
  }

  double _roundUpToOneMillion(double value) {
    const unit = 1000000;
    return ((value + unit - 1) ~/ unit) * unit.toDouble();
  }

  double _calcTopPosition(double value, double minY, double maxY, double height) {
    final ratio = (maxY - value) / (maxY - minY);
    return ratio * height;
  }
}


