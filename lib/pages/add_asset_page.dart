import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/user_id.dart';

class AddAssetPage extends StatefulWidget {
  const AddAssetPage({super.key});

  @override
  State<AddAssetPage> createState() => _AddAssetPageState();
}

class _AddAssetPageState extends State<AddAssetPage> {
  final name = TextEditingController();
  final value = TextEditingController();
  final image = TextEditingController();

  List<String> c1List = [];
  List<String> c2List = [];

  String? selectedC1;
  String? selectedC2;

  @override
  void initState() {
    super.initState();
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

  Future<void> addAsset() async {
    await Supabase.instance.client.from('assets').insert({
      'name': name.text,
      'value': int.tryParse(value.text) ?? 0,
      'category1': selectedC1,
      'category2': selectedC2,
      'image_url': image.text,
      'user_id': userId,
    });

    // Refresh categories after adding a new asset
    loadCategories();
    Navigator.pop(context);
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
      appBar: AppBar(title: const Text("AddAsset")),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: "Name"),
            ),

            TextField(
              controller: value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Amount"),
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

            ElevatedButton(onPressed: addAsset, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}