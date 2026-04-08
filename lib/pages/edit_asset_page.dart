import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/user_id.dart';

class EditAssetPage extends StatefulWidget {
  final Map asset; // 編集対象のデータ

  const EditAssetPage({super.key, required this.asset});

  @override
  State<EditAssetPage> createState() => _EditAssetPageState();
}

class _EditAssetPageState extends State<EditAssetPage> {
  late TextEditingController name;
  late TextEditingController value;
  late TextEditingController image;

  List<String> c1List = [];
  List<String> c2List = [];

  String? selectedC1;
  String? selectedC2;

  @override
  void initState() {
    super.initState();

    name = TextEditingController(text: widget.asset['name']);
    value = TextEditingController(text: widget.asset['value'].toString());
    image = TextEditingController(text: widget.asset['image_url'] ?? "");

    selectedC1 = widget.asset['category1'];
    selectedC2 = widget.asset['category2'];

    loadCategories();
  }

  Future<void> loadCategories() async {
    final data = await Supabase.instance.client
        .from('assets')
        .select('category1, category2')
        .eq('user_id', userId);

    final map = <String, Set<String>>{};

    for (var row in data) {
      final c1 = row['category1'] ?? "";
      final c2 = row['category2'] ?? "";

      if (c1.isEmpty) continue;

      map.putIfAbsent(c1, () => <String>{});
      if (c2.isNotEmpty) map[c1]!.add(c2);
    }

    setState(() {
      c1List = map.keys.toList();
      if (selectedC1 != null && map.containsKey(selectedC1)) {
        c2List = map[selectedC1]!.toList();
      }
    });
  }

  Future<void> saveAsset() async {
    await Supabase.instance.client.from('assets').update({
      'name': name.text,
      'value': int.tryParse(value.text) ?? 0,
      'category1': selectedC1,
      'category2': selectedC2,
      'image_url': image.text,
    }).eq('id', widget.asset['id']).eq('user_id', userId);

    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    name.dispose();
    value.dispose();
    image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Asset")),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: "name"),
            ),

            TextField(
              controller: value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "amount"),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: selectedC1,
              items: c1List
                  .map((c1) => DropdownMenuItem(
                        value: c1,
                        child: Text(c1),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  selectedC1 = v;
                  selectedC2 = null;
                  c2List = [];
                });
                loadCategories();
              },
              decoration: const InputDecoration(labelText: "Category"),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: selectedC2,
              items: c2List
                  .map((c2) => DropdownMenuItem(
                        value: c2,
                        child: Text(c2),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  selectedC2 = v;
                });
              },
              decoration: const InputDecoration(labelText: "Subcategory"),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: image,
              decoration: const InputDecoration(labelText: 'Image URL'),
            ),

            const SizedBox(height: 20),

            ElevatedButton(onPressed: saveAsset, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}