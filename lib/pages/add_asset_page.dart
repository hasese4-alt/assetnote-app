import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/utils/app_dialogs.dart';
import 'package:asset_note/widgets/asset_form_fields.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddAssetPage extends StatefulWidget {
  const AddAssetPage({super.key, required this.year, required this.month});

  final int year;
  final int month;

  @override
  State<AddAssetPage> createState() => _AddAssetPageState();
}

class _AddAssetPageState extends State<AddAssetPage> {
  final name = TextEditingController();
  final value = TextEditingController();

  late final AssetsRepository _repository;

  List<Map<String, dynamic>> parentCategories = [];
  Map<String, List<Map<String, dynamic>>> childCategories = {};

  String? selectedC1Id;
  String? selectedC2Id;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return widget.year == now.year && widget.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    _repository = AssetsRepository(Supabase.instance.client);
    loadCategories();
  }

  @override
  void dispose() {
    name.dispose();
    value.dispose();
    super.dispose();
  }

  Future<void> loadCategories() async {
    final h = await _repository.fetchCategoryHierarchy();
    if (!mounted) return;
    setState(() {
      parentCategories = h.parentCategories;
      childCategories = h.childCategories;
    });
  }

  String? _resolveCategory1Name() {
    if (selectedC1Id == null) return null;
    for (final c in parentCategories) {
      if (c['id'] == selectedC1Id) return c['name'] as String?;
    }
    return null;
  }

  String? _resolveCategory2Name() {
    if (selectedC2Id == null) return null;
    for (final list in childCategories.values) {
      for (final c in list) {
        if (c['id'] == selectedC2Id) return c['name'] as String?;
      }
    }
    return null;
  }

  Future<void> addAsset() async {
    if (name.text.trim().isEmpty) {
      showMissingFieldDialog(context, 'Name is required.');
      return;
    }

    if (value.text.trim().isEmpty) {
      showMissingFieldDialog(context, 'Amount is required.');
      return;
    }

    if (selectedC1Id == null) {
      showMissingFieldDialog(context, 'Category is required.');
      return;
    }

    if (_isCurrentMonth) {
      await _repository.insertAsset(
        name: name.text,
        value: int.tryParse(value.text) ?? 0,
        category1Id: selectedC1Id,
        category2Id: selectedC2Id,
      );
    } else {
      await _repository.insertAssetWithHistory(
        name: name.text,
        value: int.tryParse(value.text) ?? 0,
        category1Id: selectedC1Id,
        category2Id: selectedC2Id,
        category1Name: _resolveCategory1Name(),
        category2Name: _resolveCategory2Name(),
        year: widget.year,
        month: widget.month,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Asset')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          AssetFormFields(
            nameController: name,
            valueController: value,
            parentCategories: parentCategories,
            childCategories: childCategories,
            selectedC1Id: selectedC1Id,
            selectedC2Id: selectedC2Id,
            onParentChanged: (v) {
              setState(() {
                selectedC1Id = v;
                selectedC2Id = null;
              });
            },
            onChildChanged: (v) {
              setState(() => selectedC2Id = v);
            },
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: addAsset,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: const StadiumBorder(),
            ),
            child: const Text('Save', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
