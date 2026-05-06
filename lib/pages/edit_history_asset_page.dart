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
  late TextEditingController acquisitionPriceController;
  late final AssetsRepository _repository;

  @override
  void initState() {
    super.initState();

    _repository = AssetsRepository(Supabase.instance.client);

    nameController =
        TextEditingController(text: widget.assetHistory['name'] as String?);
    valueController =
        TextEditingController(text: widget.assetHistory['value'].toString());
    acquisitionPriceController = TextEditingController(
      text: widget.assetHistory['acquisition_price']?.toString() ?? '',
    );
  }

  Future<void> save() async {
    final rawId = widget.assetHistory['id'];
    final id = rawId is int ? rawId : (rawId as num).toInt();
    final parsedValue = int.tryParse(valueController.text.trim());

    if (parsedValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金額は数値で入力してください。')),
      );
      return;
    }

    await _repository.updateAssetsHistoryRow(
      id: id,
      name: nameController.text.trim(),
      value: parsedValue,
      acquisitionPrice: int.tryParse(acquisitionPriceController.text.trim()),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    nameController.dispose();
    valueController.dispose();
    acquisitionPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('過去の資産を編集')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '名称',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(
                labelText: '金額',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: acquisitionPriceController,
              decoration: const InputDecoration(
                labelText: '取得価格（任意）',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: save,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
