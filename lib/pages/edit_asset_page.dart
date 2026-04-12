import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/utils/app_dialogs.dart';
import 'package:asset_note/widgets/asset_form_fields.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditAssetPage extends StatefulWidget {
  const EditAssetPage({super.key, required this.asset});

  final Map<String, dynamic> asset;

  @override
  State<EditAssetPage> createState() => _EditAssetPageState();
}

class _EditAssetPageState extends State<EditAssetPage> {
  late TextEditingController name;
  late TextEditingController value;

  late final AssetsRepository _repository;

  List<Map<String, dynamic>> parentCategories = [];
  Map<String, List<Map<String, dynamic>>> childCategories = {};

  String? selectedC1Id;
  String? selectedC2Id;

  @override
  void initState() {
    super.initState();

    name = TextEditingController(
      text: widget.asset['name']?.toString() ?? '',
    );
    value = TextEditingController(text: widget.asset['value'].toString());

    selectedC1Id = widget.asset['category1_id'] as String?;
    selectedC2Id = widget.asset['category2_id'] as String?;

    _repository = AssetsRepository(Supabase.instance.client);
    loadCategories();
  }

  Future<void> loadCategories() async {
    final h = await _repository.fetchCategoryHierarchy();
    if (!mounted) return;
    setState(() {
      parentCategories = h.parentCategories;
      childCategories = h.childCategories;
    });
  }

  Future<void> saveAsset() async {
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

    final rawId = widget.asset['id'];
    final assetId = rawId is int ? rawId : (rawId as num).toInt();

    await _repository.updateAsset(
      id: assetId,
      name: name.text,
      value: int.tryParse(value.text) ?? 0,
      category1Id: selectedC1Id,
      category2Id: selectedC2Id,
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    name.dispose();
    value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit asset')),
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
                onPressed: saveAsset,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
