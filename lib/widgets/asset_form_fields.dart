import 'package:flutter/material.dart';

/// Shared name, amount, and category fields for add/edit asset screens.
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name *',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: valueController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount *',
          ),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: selectedC1Id,
          decoration: const InputDecoration(
            labelText: 'Category *',
          ),
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
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedC2Id,
          decoration: const InputDecoration(
            labelText: 'Subcategory',
          ),
          items: (childCategories[selectedC1Id] ?? [])
              .map(
                (c) => DropdownMenuItem(
                  value: c['id'] as String,
                  child: Text(c['name'] as String),
                ),
              )
              .toList(),
          onChanged: selectedC1Id == null ? null : onChildChanged,
        ),
      ],
    );
  }
}
