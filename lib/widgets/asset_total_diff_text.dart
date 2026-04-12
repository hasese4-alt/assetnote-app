import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Green/red diff line used on the assets list (totals and categories).
class AssetTotalDiffText extends StatelessWidget {
  const AssetTotalDiffText({
    super.key,
    required this.formatter,
    required this.currentTotal,
    required this.startTotal,
    required this.fontSize,
  });

  final NumberFormat formatter;
  final int currentTotal;
  final int startTotal;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final diff = currentTotal - startTotal;
    final diffRate =
        startTotal > 0 ? (currentTotal / startTotal - 1) * 100 : 0.0;
    return Text(
      '${diff >= 0 ? '+' : ''}${formatter.format(diff)} '
      '(${diffRate.toStringAsFixed(1)}%)',
      style: TextStyle(
        fontSize: fontSize,
        color: diff >= 0 ? Colors.green : Colors.red,
      ),
    );
  }
}
