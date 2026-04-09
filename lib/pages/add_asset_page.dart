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

  List<Map<String, dynamic>> parentCategories = [];
  Map<String, List<Map<String, dynamic>>> childCategories = {};

  String? selectedC1Id;
  String? selectedC2Id;

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    final client = Supabase.instance.client;

    final parents = await client
        .from('categories1')
        .select('id, name')
        .eq('user_id', userId);

    final children = await client
        .from('categories2')
        .select('id, parent_id, name')
        .eq('user_id', userId);

    final map = <String, List<Map<String, dynamic>>>{};

    for (final c in children) {
      final pid = c['parent_id'];
      map.putIfAbsent(pid, () => []);
      map[pid]!.add(Map<String, dynamic>.from(c));
    }

    setState(() {
      parentCategories = List<Map<String, dynamic>>.from(parents);
      childCategories = map;
    });
  }

  Future<void> addAsset() async {
    final uid = Supabase.instance.client.auth.currentUser!.id;

    await Supabase.instance.client.from('assets').insert({
      'name': name.text,
      'value': int.tryParse(value.text) ?? 0,
      'category1_id': selectedC1Id,
      'category2_id': selectedC2Id,
      'image_url': image.text,
      'user_id': uid,
    });

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
      appBar: AppBar(title: const Text("Add Asset")),
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

            // 親カテゴリ
            DropdownButtonFormField<String>(
              value: selectedC1Id,
              items: parentCategories
                  .map(
                    (p) => DropdownMenuItem(
                      value: p['id'] as String, // ← これが重要
                      child: Text(p['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  selectedC1Id = v;
                  selectedC2Id = null;
                });
              },
              decoration: const InputDecoration(labelText: "Category"),
            ),

            const SizedBox(height: 10),

            // 子カテゴリ
            DropdownButtonFormField<String>(
              value: selectedC2Id,
              items: (childCategories[selectedC1Id] ?? [])
                  .map(
                    (c) => DropdownMenuItem(
                      value: c['id'] as String, // ← 重要
                      child: Text(c['name'] as String), // ← 重要
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  selectedC2Id = v;
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
