import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/utils/app_dialogs.dart';
import 'package:asset_note/widgets/asset_form_fields.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddAssetPage extends StatefulWidget {
  const AddAssetPage({super.key});

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

    await _repository.insertAsset(
      name: name.text,
      value: int.tryParse(value.text) ?? 0,
      category1Id: selectedC1Id,
      category2Id: selectedC2Id,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add asset')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
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
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: addAsset,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
