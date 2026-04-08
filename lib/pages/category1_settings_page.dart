import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/user_id.dart';

class Category1SettingsPage extends StatefulWidget {
  const Category1SettingsPage({super.key});

  @override
  State<Category1SettingsPage> createState() => _Category1SettingsPageState();
}

class _Category1SettingsPageState extends State<Category1SettingsPage> {
  final TextEditingController _categoryController = TextEditingController();
  List<String> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await Supabase.instance.client
          .from('assets')
          .select('category1')
          .eq('user_id', userId)
          .not('category1', 'is', null)
          .not('category1', 'eq', '');

      // Dart側で distinct
      final set = <String>{};
      for (final row in data) {
        final c = row['category1'] as String?;
        if (c != null && c.isNotEmpty) {
          set.add(c);
        }
      }

      setState(() {
        categories = set.toList()..sort();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load categories')),
      );
    }
  }

  Future<void> addCategory() async {
    final newCategory = _categoryController.text.trim();

    if (newCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name')),
      );
      return;
    }

    if (categories.contains(newCategory)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category already exists')),
      );
      return;
    }

    try {
      // ダミー asset を作成して category1 を保存
      await Supabase.instance.client.from('assets').insert({
        'name': 'Dummy asset for category',
        'value': 0,
        'category1': newCategory,
        'user_id': userId,
      });

      // ダミー削除
      await Supabase.instance.client
          .from('assets')
          .delete()
          .eq('category1', newCategory)
          .eq('name', 'Dummy asset for category');

      setState(() {
        categories.add(newCategory);
        categories.sort();
        _categoryController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add category')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (isLoading)
              const LinearProgressIndicator()
            else
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'New Category',
                  hintText: 'Enter new category name',
                ),
              ),
            if (!isLoading)
              ElevatedButton(
                onPressed: addCategory,
                child: const Text('Add Category'),
              ),
            const SizedBox(height: 20),
            if (!isLoading)
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(categories[index]),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}