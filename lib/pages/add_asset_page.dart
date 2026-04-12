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
    // ★ Name 必須
    if (name.text.trim().isEmpty) {
      _showError("Name is required");
      return;
    }

    // ★ Amount 必須
    if (value.text.trim().isEmpty) {
      _showError("Amount is required");
      return;
    }

    // ★ Category 必須
    if (selectedC1Id == null) {
      _showError("Category is required");
      return;
    }

    final uid = Supabase.instance.client.auth.currentUser!.id;

    await Supabase.instance.client.from('assets').insert({
      'name': name.text,
      'value': int.tryParse(value.text) ?? 0,
      'category1_id': selectedC1Id,
      'category2_id': selectedC2Id,
      'user_id': uid,
    });

    Navigator.pop(context);
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Missing Field"),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Asset")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            // ★ Name（必須）
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: "Name *",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // ★ Amount（必須）
            TextField(
              controller: value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Amount *",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // ★ 第一分類（必須）
            DropdownButtonFormField<String>(
              value: selectedC1Id,
              decoration: const InputDecoration(
                labelText: "Category *",
                border: OutlineInputBorder(),
              ),
              items: parentCategories
                  .map(
                    (p) => DropdownMenuItem(
                      value: p['id'] as String,
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
            ),

            const SizedBox(height: 16),

            // ★ 第二分類（第一分類が選ばれたときだけ）
            DropdownButtonFormField<String>(
              value: selectedC2Id,
              decoration: const InputDecoration(
                labelText: "Subcategory",
                border: OutlineInputBorder(),
              ),
              items: (childCategories[selectedC1Id] ?? [])
                  .map(
                    (c) => DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text(c['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: selectedC1Id == null
                  ? null
                  : (v) {
                      setState(() => selectedC2Id = v);
                    },
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
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