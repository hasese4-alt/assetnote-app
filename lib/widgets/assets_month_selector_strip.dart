import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Horizontal month picker (36 months from 18 months ago).
class AssetsMonthSelectorStrip extends StatelessWidget {
  const AssetsMonthSelectorStrip({
    super.key,
    required this.scrollController,
    required this.viewYear,
    required this.viewMonth,
    required this.isMonthConfirmed,
    required this.onMonthTap,
  });

  final ScrollController scrollController;
  final int viewYear;
  final int viewMonth;
  final bool Function(int year, int month) isMonthConfirmed;
  final Future<void> Function(int year, int month) onMonthTap;

  static const _itemCount = 36;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('yyyy/MM');
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 18);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return SizedBox(
      height: 70,
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _itemCount,
        itemBuilder: (context, index) {
          final date = DateTime(start.year, start.month + index);
          final label = dateFmt.format(date);
          final isCurrent =
              date.year == viewYear && date.month == viewMonth;
          final confirmed = isMonthConfirmed(date.year, date.month);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onMonthTap(date.year, date.month),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? (isLight ? Colors.white : const Color(0xFF3A3A3C))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCurrent
                        ? (isLight ? Colors.black : Colors.white)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 月ラベル
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // ★ 確定アイコン（文字なし）
                    confirmed
                        ? Icon(
                            Icons.check,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}