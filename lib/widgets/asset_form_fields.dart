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
    final subItems = childCategories[selectedC1Id] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
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
          Divider(height: 0.5, thickness: 0.5, indent: 16, color: dividerColor),
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
          if (acquisitionPriceController != null) ...[
            Divider(
                height: 0.5, thickness: 0.5, indent: 16, color: dividerColor),
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
          Divider(height: 0.5, thickness: 0.5, indent: 16, color: dividerColor),
          _FormRow(
            label: 'カテゴリ',
            labelColor: labelColor,
            child: DropdownButton<String>(
              value: selectedC1Id,
              hint: Text('選択してください',
                  style: TextStyle(color: hintColor, fontSize: 17)),
              underline: const SizedBox.shrink(),
              isExpanded: true,
              alignment: AlignmentDirectional.centerStart,
              icon: const Icon(Icons.chevron_right, size: 18),
              style: const TextStyle(fontSize: 17),
              items: parentCategories
                  .map(
                    (p) => DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text(p['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: onParentChanged,
            ),
          ),
          if (selectedC1Id != null) ...[
            Divider(
                height: 0.5, thickness: 0.5, indent: 16, color: dividerColor),
            _FormRow(
              label: 'サブカテゴリ',
              labelColor: labelColor,
              child: DropdownButton<String>(
                value: selectedC2Id,
                hint: Text('なし',
                    style: TextStyle(color: hintColor, fontSize: 17)),
                underline: const SizedBox.shrink(),
                isExpanded: true,
                alignment: AlignmentDirectional.centerStart,
                icon: const Icon(Icons.chevron_right, size: 18),
                style: const TextStyle(fontSize: 17),
                items: subItems
                    .map(
                      (c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: subItems.isEmpty ? null : onChildChanged,
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
