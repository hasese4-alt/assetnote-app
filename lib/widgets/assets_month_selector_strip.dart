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
    this.isProcessing = false,
    required this.stripEnd,
    this.showConfirmButton = true,
    this.onResetLongPress,
  });

  final ScrollController scrollController;
  final int viewYear;
  final int viewMonth;
  final bool Function(int year, int month) isMonthConfirmed;
  final Future<void> Function(int year, int month) onMonthTap;
  final VoidCallback onConfirmTap;
  final bool isConfirmed;
  final bool isProcessing;
  final DateTime stripEnd;
  final bool showConfirmButton;

  /// 長押しリセットのコールバック。null の場合は長押し無効。
  final VoidCallback? onResetLongPress;

  /// 表示範囲内で最も新しい未確定月を返す。
  DateTime? _latestUnconfirmedDate(DateTime start, int monthsToShow) {
    DateTime? latest;
    for (int i = 0; i < monthsToShow; i++) {
      final date = DateTime(start.year, start.month + i);
      if (!isMonthConfirmed(date.year, date.month)) {
        if (latest == null || date.isAfter(latest)) latest = date;
      }
    }
    return latest;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 18);

    final monthsToShow =
        (stripEnd.year - start.year) * 12 + (stripEnd.month - start.month) + 1;

    final latestUnconfirmed = _latestUnconfirmedDate(start, monthsToShow);

    final isLight = Theme.of(context).brightness == Brightness.light;
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

                // 現在表示中 かつ 最新未確定月 のみ長押し有効
                final isResettable = onResetLongPress != null &&
                    isCurrent &&
                    latestUnconfirmed != null &&
                    date.year == latestUnconfirmed.year &&
                    date.month == latestUnconfirmed.month;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: isProcessing ? null : () => onMonthTap(date.year, date.month),
                    onLongPress: (isResettable && !isProcessing) ? onResetLongPress : null,
                    child: Container(
                      width: 48,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? (isLight ? Colors.white : const Color(0xFF3A3A3C))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.withValues(alpha: 0.3),
                          width: isCurrent ? 1.5 : 1.0,
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
                              color: Colors.grey
                                  .withValues(alpha: showYear ? 0.7 : 0.0),
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
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: isProcessing ? null : onConfirmTap,
                child: Container(
                  width: 64,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isConfirmed
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isProcessing
                      ? Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isConfirmed
                                  ? Colors.white
                                  : Colors.grey[600],
                            ),
                          ),
                        )
                      : Text(
                          isConfirmed ? '確定済' : '未確定',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: isConfirmed ? Colors.white : Colors.grey[800],
                            fontWeight: FontWeight.bold,
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
