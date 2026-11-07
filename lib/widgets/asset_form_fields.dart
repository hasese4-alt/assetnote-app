import 'package:asset_note/utils/category_favicon.dart';
import 'package:asset_note/widgets/icon_picker_sheet.dart';
import 'package:flutter/material.dart';

class AssetFormFields extends StatelessWidget {
  const AssetFormFields({
    super.key,
    required this.nameController,
    required this.valueController,
    required this.parentCategories,
    required this.childCategories,
    required this.selectedC1Id,
    required this.selectedC2Id,
    required this.onParentChanged,
    required this.onChildChanged,
    this.acquisitionPriceController,
    this.iconLabel,
    this.iconTextColor,
    this.iconBgColor,
    this.onIconChanged,
    this.hideFavicon = false,
    this.onHideFaviconChanged,
  });

  final TextEditingController nameController;
  final TextEditingController valueController;
  final List<Map<String, dynamic>> parentCategories;
  final Map<String, List<Map<String, dynamic>>> childCategories;
  final String? selectedC1Id;
  final String? selectedC2Id;
  final ValueChanged<String?> onParentChanged;
  final ValueChanged<String?> onChildChanged;
  final TextEditingController? acquisitionPriceController;
  final String? iconLabel;
  final Color? iconTextColor;
  final Color? iconBgColor;
  final void Function(String label, Color textColor, Color bgColor)? onIconChanged;
  final bool hideFavicon;
  final ValueChanged<bool>? onHideFaviconChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final dividerColor =
        isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
    final labelColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);
    final hintColor =
        isDark ? const Color(0xFF636366) : const Color(0xFFAEAEB2);
    final primary = theme.colorScheme.primary;
    final subItems = childCategories[selectedC1Id] ?? [];

    final hasIcon = iconLabel != null && iconLabel!.isNotEmpty;
    final effectiveTextColor = iconTextColor ?? Colors.white;
    final effectiveBgColor = iconBgColor ?? const Color(0xFF007AFF);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // ── 名称 ──────────────────────────────────────────────
          _FormRow(
            label: '名称',
            labelColor: labelColor,
            child: TextField(
              controller: nameController,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '必須',
                hintStyle: TextStyle(color: hintColor, fontSize: 17),
              ),
            ),
          ),

          // ── ファビコントグル（名称マッチ時） ──────────────────
          ListenableBuilder(
            listenable: nameController,
            builder: (ctx, _) {
              final faviconUrl =
                  faviconUrlForCategoryLabel(nameController.text);
              if (faviconUrl == null) return const SizedBox.shrink();
              return Column(
                children: [
                  Divider(
                      height: 0.5,
                      thickness: 0.5,
                      indent: 16,
                      color: dividerColor),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Opacity(
                          opacity: hideFavicon ? 0.3 : 1.0,
                          child: Image.network(
                            faviconUrl,
                            width: 20,
                            height: 20,
                            errorBuilder: (_, _, _) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'アイコンを使用',
                            style: TextStyle(
                              fontSize: 15,
                              color:
                                  isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: !hideFavicon,
                          activeTrackColor: primary,
                          onChanged: onHideFaviconChanged != null
                              ? (v) => onHideFaviconChanged!(!v)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // ── カスタムアイコン ───────────────────────────────────
          if (onIconChanged != null) ...[
            Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 16,
                color: dividerColor),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final result = await showIconPickerSheet(
                  context,
                  currentLabel: iconLabel,
                  currentTextColor: effectiveTextColor,
                  currentBgColor: effectiveBgColor,
                );
                if (result != null) {
                  onIconChanged!(
                      result.label, result.textColor, result.bgColor);
                }
              },
              child: _FormRow(
                label: 'アイコン',
                labelColor: labelColor,
                child: Row(
                  children: [
                    if (hasIcon)
                      IconPreview(
                        label: iconLabel!,
                        textColor: effectiveTextColor,
                        bgColor: effectiveBgColor,
                        size: 22,
                      )
                    else
                      Text(
                        '未設定',
                        style: TextStyle(fontSize: 17, color: hintColor),
                      ),
                    const Spacer(),
                    Icon(Icons.chevron_right, size: 18, color: hintColor),
                  ],
                ),
              ),
            ),
          ],

          // ── 金額 ──────────────────────────────────────────────
          Divider(
              height: 0.5, thickness: 0.5, indent: 16, color: dividerColor),
          _FormRow(
            label: '金額',
            labelColor: labelColor,
            child: TextField(
              controller: valueController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '必須',
                hintStyle: TextStyle(color: hintColor, fontSize: 17),
              ),
            ),
          ),

          // ── 取得価格 ──────────────────────────────────────────
          if (acquisitionPriceController != null) ...[
            Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 16,
                color: dividerColor),
            _FormRow(
              label: '取得価格',
              labelColor: labelColor,
              child: TextField(
                controller: acquisitionPriceController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '任意',
                  hintStyle: TextStyle(color: hintColor, fontSize: 17),
                ),
              ),
            ),
          ],

          // ── カテゴリ ──────────────────────────────────────────
          Divider(
              height: 0.5, thickness: 0.5, indent: 16, color: dividerColor),
          _FormRow(
            label: 'カテゴリ',
            labelColor: labelColor,
            child: SizedBox(
              height: 22,
              child: DropdownButton<String>(
                value: selectedC1Id,
                hint: Text('選択してください',
                    style: TextStyle(color: hintColor, fontSize: 17)),
                underline: const SizedBox.shrink(),
                isExpanded: true,
                alignment: AlignmentDirectional.centerStart,
                icon: const Icon(Icons.chevron_right, size: 18),
                style: TextStyle(
                    fontSize: 17, color: theme.colorScheme.onSurface),
                items: parentCategories
                    .map(
                      (p) => DropdownMenuItem(
                        value: p['id'] as String,
                        child: Text(
                          p['name'] as String,
                          style:
                              TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onParentChanged,
              ),
            ),
          ),

          // ── サブカテゴリ ──────────────────────────────────────
          if (selectedC1Id != null) ...[
            Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 16,
                color: dividerColor),
            _FormRow(
              label: 'サブカテゴリ',
              labelColor: labelColor,
              child: SizedBox(
                height: 22,
                child: DropdownButton<String>(
                  value: selectedC2Id,
                  hint: Text('なし',
                      style: TextStyle(color: hintColor, fontSize: 17)),
                  underline: const SizedBox.shrink(),
                  isExpanded: true,
                  alignment: AlignmentDirectional.centerStart,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  style: TextStyle(
                      fontSize: 17, color: theme.colorScheme.onSurface),
                  items: subItems
                      .map(
                        (c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text(
                            c['name'] as String,
                            style: TextStyle(
                                color: theme.colorScheme.onSurface),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: subItems.isEmpty ? null : onChildChanged,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({
    required this.label,
    required this.labelColor,
    required this.child,
  });

  final String label;
  final Color labelColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
