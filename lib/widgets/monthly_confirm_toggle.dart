import 'package:flutter/material.dart';

class MonthlyConfirmToggle extends StatelessWidget {
  const MonthlyConfirmToggle({
    super.key,
    required this.isConfirmed,
    required this.onTap,
    this.size = 40,
  });

  final bool isConfirmed;
  final Future<void> Function() onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: size * 0.25,
          horizontal: size * 0.45,
        ),
        decoration: BoxDecoration(
          color: isConfirmed
              ? (isDark
                  ? Colors.green.withOpacity(0.20)
                  : Colors.green.withOpacity(0.10))
              : (isDark
                  ? Colors.grey.withOpacity(0.20)
                  : Colors.grey.withOpacity(0.12)),
          borderRadius: BorderRadius.circular(size * 0.6),
          border: Border.all(
            color: isConfirmed
                ? (isDark
                    ? Colors.green.withOpacity(0.6)
                    : Colors.green.withOpacity(0.5))
                : (isDark
                    ? Colors.grey.withOpacity(0.6)
                    : Colors.grey.withOpacity(0.5)),
          ),
        ),
        child: Text(
          isConfirmed ? 'Confirmed' : 'Tentative',
          style: TextStyle(
            fontSize: size * 0.40,
            fontWeight: FontWeight.w500,
            color: isConfirmed
                ? (isDark ? Colors.green.shade300 : Colors.green.shade600)
                : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }
}