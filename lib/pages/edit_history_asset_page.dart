import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/user_id.dart';

class EditHistoryAssetPage extends StatefulWidget {
  final Map<String, dynamic> assetHistory;

  const EditHistoryAssetPage({
    super.key,
    required this.assetHistory,
  });

  @override
  State<EditHistoryAssetPage> createState() => _EditHistoryAssetPageState();
}

class _EditHistoryAssetPageState extends State<EditHistoryAssetPage> {
  late TextEditingController nameController;
  late TextEditingController valueController;

  String? category1;
  String? category2;
  String? category3;

  @override
  void initState() {
    super.initState();

    nameController =
        TextEditingController(text: widget.assetHistory['name']);
    valueController =
        TextEditingController(text: widget.assetHistory['value'].toString());

    category1 = widget.assetHistory['category1'];
    category2 = widget.assetHistory['category2'];
    category3 = widget.assetHistory['category3'];
  }

  Future<void> save() async {
    final id = widget.assetHistory['id'];
    final parsedValue = int.tryParse(valueController.text.trim());

    if (parsedValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a numeric amount.')),
      );
      return;
    }

    await Supabase.instance.client
        .from('assets_history')
        .update({
          'name': nameController.text.trim(),
          'value': parsedValue,
          'category1': category1,
          'category2': category2,
          'category3': category3,
        })
        .eq('id', id)
        .eq('user_id', userId)
        .select();

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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "name"),
            ),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(labelText: "amount"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}