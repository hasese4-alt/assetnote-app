import 'package:asset_note/theme/app_tokens.dart';
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
                            ? context.colors.surface
                            : Colors.transparent,
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : context.colors.opaqueSeparator,
                          width: isCurrent ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            showYear ? '${date.year}' : '',
                            style: TextStyle(
                              fontSize: AppFont.caption2,
                              height: 1.2,
                              color: showYear ? context.colors.secondaryLabel : Colors.transparent,
                            ),
                          ),
                          Text(
                            '${date.month}月',
                            style: TextStyle(
                              fontSize: AppFont.subheadline,
                              fontWeight: isCurrent
                                  ? AppFont.bold
                                  : AppFont.regular,
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
                        : context.colors.fill,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: isProcessing
                      ? Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isConfirmed
                                  ? context.colors.onAccent
                                  : context.colors.secondaryLabel,
                            ),
                          ),
                        )
                      : Text(
                          isConfirmed ? '確定済' : '未確定',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppFont.caption2,
                            color: isConfirmed ? context.colors.onAccent : context.colors.label,
                            fontWeight: AppFont.bold,
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
