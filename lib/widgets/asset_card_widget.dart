import 'package:asset_note/utils/category_favicon.dart';
import 'package:asset_note/widgets/icon_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AssetCardWidget extends StatelessWidget {
  const AssetCardWidget({
    super.key,
    required this.asset,
    required this.isConfirmed,
    required this.isCurrentMonth,
    required this.formatter,
    required this.startOfYearValue,
    required this.onEditCurrent,
    required this.onEditHistory,
    required this.onDelete,
    required this.onUnsell,
    this.onCopy,
    this.isGrouped = false,
    this.isNewThisMonth = false,
  });

  final Map<String, dynamic> asset;
  final bool isConfirmed;
  final bool isCurrentMonth;
  final NumberFormat formatter;
  final int? startOfYearValue;
  final Future<void> Function() onEditCurrent;
  final Future<void> Function() onEditHistory;
  final VoidCallback onDelete;
  final Future<void> Function() onUnsell;
  final Future<void> Function()? onCopy;
  final bool isGrouped;
  final bool isNewThisMonth;

  @override
  Widget build(BuildContext context) {
    final start = startOfYearValue;
    final current = asset['value'] as int? ?? 0;
    final isSold = asset['is_sold'] as bool? ?? false;

    int diff = 0;
    double diffRate = 0;

    if (start != null && start > 0) {
      diff = current - start;
      diffRate = (current / start - 1) * 100;
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rowContent = Row(
      children: [
        _AssetIcon(
          name: asset['name'] as String? ?? '',
          category2Name: asset['category2_name'] as String? ?? '',
          hideFavicon: asset['hide_favicon'] as bool? ?? false,
          cs: cs,
          iconLabel: asset['icon_label'] as String?,
          iconTextColor: hexToColor(asset['icon_text_color'] as String?),
          iconBgColor: hexToColor(asset['icon_bg_color'] as String?),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((asset['category2_name'] as String? ?? '').isNotEmpty)
                Text(
                  asset['category2_name'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      asset['name'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isSold) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC1E32).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '売却済',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC1E32),
                        ),
                      ),
                    ),
                  ],
                  if (isNewThisMonth) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatter.format(current),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (start != null && !isSold)
              Text(
                "${diff >= 0 ? '+' : ''}${formatter.format(diff)} (${diffRate.toStringAsFixed(1)}%)",
                style: TextStyle(
                  fontSize: 11,
                  color: diff >= 0
                      ? const Color(0xFF00963C)
                      : const Color(0xFFDC1E32),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        if (isConfirmed) Icon(Icons.lock, size: 15, color: cs.primary),
      ],
    );

    final decoratedChild = isGrouped
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: rowContent,
          )
        : Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSold
                  ? (isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF2F2F7))
                  : cs.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: rowContent,
          );

    return RepaintBoundary(
      child: Opacity(
        opacity: isSold ? 0.55 : 1.0,
        child: GestureDetector(
          onTap: () async {
            if (isConfirmed) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('この月は確定済みのため編集できません。'),
                ),
              );
              return;
            }

            if (isSold) {
              await onUnsell();
              return;
            }

            if (isCurrentMonth) {
              await onEditCurrent();
            } else {
              await onEditHistory();
            }
          },
          onLongPress: () {
            if (isConfirmed) return;
            _showActionSheet(context);
          },
          child: decoratedChild,
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    final name = asset['name'] as String? ?? '';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            if (onCopy != null) ...[
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('コピーして複製'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await onCopy!();
                },
              ),
              const Divider(height: 1, indent: 16),
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('削除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteDialog(context, name);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String name) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('資産を削除しますか？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'この操作は取り消せません',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '損益・取引履歴は記録されず、データが完全に消去されます。',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              onDelete();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}

class _AssetIcon extends StatelessWidget {
  const _AssetIcon({
    required this.name,
    required this.category2Name,
    required this.hideFavicon,
    required this.cs,
    this.iconLabel,
    this.iconTextColor,
    this.iconBgColor,
  });

  final String name;
  final String category2Name;
  final bool hideFavicon;
  final ColorScheme cs;
  final String? iconLabel;
  final Color? iconTextColor;
  final Color? iconBgColor;

  @override
  Widget build(BuildContext context) {
    if (iconLabel != null && iconLabel!.isNotEmpty) {
      return IconPreview(
        label: iconLabel!,
        textColor: iconTextColor ?? Colors.white,
        bgColor: iconBgColor ?? cs.primary,
        size: 30,
      );
    }

    final url = faviconUrlForCategoryLabel(category2Name) ??
        (hideFavicon ? null : faviconUrlForCategoryLabel(name));
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: url != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.network(
                url,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (context2, e, stack) => _fallbackText(),
              ),
            )
          : _fallbackText(),
    );
  }

  Widget _fallbackText() => Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: cs.primary,
        ),
      );
}
