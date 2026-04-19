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
  });

  final TextEditingController nameController;
  final TextEditingController valueController;
  final List<Map<String, dynamic>> parentCategories;
  final Map<String, List<Map<String, dynamic>>> childCategories;
  final String? selectedC1Id;
  final String? selectedC2Id;
  final ValueChanged<String?> onParentChanged;
  final ValueChanged<String?> onChildChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final dividerColor =
        isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
    final hintColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFFAEAEB2);
    final subItems = childCategories[selectedC1Id] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _FormRow(
            label: 'Name',
            child: TextField(
              controller: nameController,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration.collapsed(
                hintText: 'Required',
                hintStyle: TextStyle(color: hintColor),
              ),
            ),
          ),
          Divider(height: 0.5, thickness: 0.5, indent: 16, color: dividerColor),
          _FormRow(
            label: 'Amount',
            child: TextField(
              controller: valueController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration.collapsed(
                hintText: 'Required',
                hintStyle: TextStyle(color: hintColor),
              ),
            ),
          ),
          Divider(height: 0.5, thickness: 0.5, indent: 16, color: dividerColor),
          _FormRow(
            label: 'Category',
            child: DropdownButton<String>(
              value: selectedC1Id,
              hint: Text('Select', style: TextStyle(color: hintColor, fontSize: 14)),
              underline: const SizedBox.shrink(),
              alignment: AlignmentDirectional.centerEnd,
              icon: const Icon(Icons.chevron_right, size: 18),
              style: theme.textTheme.bodyMedium,
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
              label: 'Subcategory',
              child: DropdownButton<String>(
                value: selectedC2Id,
                hint: Text('None', style: TextStyle(color: hintColor, fontSize: 14)),
                underline: const SizedBox.shrink(),
                alignment: AlignmentDirectional.centerEnd,
                icon: const Icon(Icons.chevron_right, size: 18),
                style: theme.textTheme.bodyMedium,
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
  const _FormRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}
