import 'package:flutter/material.dart';

class AssetsMonthSelectorStrip extends StatelessWidget {
  const AssetsMonthSelectorStrip({
    super.key,
    required this.scrollController,
    required this.viewYear,
    required this.viewMonth,
    required this.isMonthConfirmed,
    required this.onMonthTap,
    required this.onConfirmTap,
    required this.isConfirmed,
    required this.stripEnd,
  });

  final ScrollController scrollController;
  final int viewYear;
  final int viewMonth;
  final bool Function(int year, int month) isMonthConfirmed;
  final Future<void> Function(int year, int month) onMonthTap;
  final VoidCallback onConfirmTap;
  final bool isConfirmed;

  /// 表示する最終月（inclusive）。親が確定状態から算出して渡す。
  final DateTime stripEnd;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 18);

    final monthsToShow =
        (stripEnd.year - start.year) * 12 + (stripEnd.month - start.month) + 1;

    final isLight = Theme.of(context).brightness == Brightness.light;
    final isViewingCurrentMonth = viewYear == now.year && viewMonth == now.month;
    final showConfirmButton = isViewingCurrentMonth || isConfirmed;

    return SizedBox(
      height: 70,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20, right: 8),
              itemCount: monthsToShow,
              itemBuilder: (context, index) {
                final date = DateTime(start.year, start.month + index);
                final isCurrent =
                    date.year == viewYear && date.month == viewMonth;
                final confirmed = isMonthConfirmed(date.year, date.month);
                final showYear = index == 0 || date.month == 1;

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
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            showYear ? '${date.year}' : '',
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.2,
                              color: Colors.grey.withValues(alpha: showYear ? 0.7 : 0.0),
                            ),
                          ),
                          Text(
                            '${date.month}月',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          confirmed
                              ? Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (showConfirmButton)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: GestureDetector(
                onTap: onConfirmTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isConfirmed
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isConfirmed ? '確定済' : '確定',
                    style: TextStyle(
                      color: isConfirmed ? Colors.white : Colors.grey[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
