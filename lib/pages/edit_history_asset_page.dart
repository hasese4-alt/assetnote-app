import 'package:asset_note/services/assets_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditHistoryAssetPage extends StatefulWidget {
  const EditHistoryAssetPage({
    super.key,
    required this.assetHistory,
  });

  final Map<String, dynamic> assetHistory;

  @override
  State<EditHistoryAssetPage> createState() => _EditHistoryAssetPageState();
}

class _EditHistoryAssetPageState extends State<EditHistoryAssetPage> {
  late TextEditingController nameController;
  late TextEditingController valueController;
  late final AssetsRepository _repository;

  @override
  void initState() {
    super.initState();

    _repository = AssetsRepository(Supabase.instance.client);

    nameController =
        TextEditingController(text: widget.assetHistory['name'] as String?);
    valueController =
        TextEditingController(text: widget.assetHistory['value'].toString());
  }

  Future<void> save() async {
    final rawId = widget.assetHistory['id'];
    final id = rawId is int ? rawId : (rawId as num).toInt();
    final parsedValue = int.tryParse(valueController.text.trim());

    if (parsedValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a numeric amount.')),
      );
      return;
    }

    await _repository.updateAssetsHistoryRow(
      id: id,
      name: nameController.text.trim(),
      value: parsedValue,
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    nameController.dispose();
    valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit past month asset')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(
                labelText: 'Amount',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
