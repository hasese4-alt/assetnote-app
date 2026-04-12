import 'package:asset_note/services/assets_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/user_id.dart';

class CategorySettingsPage extends StatefulWidget {
  const CategorySettingsPage({super.key});

  @override
  State<CategorySettingsPage> createState() => _CategorySettingsPageState();
}

class _CategorySettingsPageState extends State<CategorySettingsPage> {
  List<Map<String, dynamic>> parents = [];
  Map<String, List<Map<String, dynamic>>> children = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> _editCategory(
    BuildContext context,
    Map<String, dynamic> category,
  ) async {
    final controller = TextEditingController(text: category['name'] as String?);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              await Supabase.instance.client
                  .from('categories1')
                  .update({'name': newName})
                  .eq('id', category['id']);
              if (!context.mounted) return;
              Navigator.pop(ctx);
              await loadAll();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editSubCategory(
    BuildContext context,
    String childId,
    String oldName,
  ) async {
    final controller = TextEditingController(text: oldName);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename subcategory'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              await Supabase.instance.client
                  .from('categories2')
                  .update({'name': newName})
                  .eq('id', childId);
              if (!context.mounted) return;
              Navigator.pop(ctx);
              await loadAll();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> loadAll() async {
    setState(() => isLoading = true);

    final repo = AssetsRepository(Supabase.instance.client);
    final h = await repo.fetchCategoryHierarchy();

    final map = <String, List<Map<String, dynamic>>>{};
    for (final p in h.parentCategories) {
      final pid = p['id'] as String;
      map[pid] = List<Map<String, dynamic>>.from(h.childCategories[pid] ?? []);
    }

    setState(() {
      parents = h.parentCategories;
      children = map;
      isLoading = false;
    });
  }

  Future<void> addParent() async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await Supabase.instance.client.from('categories1').insert({
                'user_id': userId,
                'name': name,
              });
              if (!context.mounted) return;
              Navigator.pop(ctx);
              await loadAll();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> addChild(String parentId) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add subcategory'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Subcategory name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await Supabase.instance.client.from('categories2').insert({
                'user_id': userId,
                'parent_id': parentId,
                'name': name,
              });
              if (!context.mounted) return;
              Navigator.pop(ctx);
              await loadAll();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> deleteParent(String id) async {
    final hasAssets = await _hasLinkedAssets(parentId: id);

    if (hasAssets) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot delete'),
          content: const Text(
            'This category is used by existing assets.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await Supabase.instance.client.from('categories1').delete().eq('id', id);
    loadAll();
  }

  Future<void> deleteChild(String parentId, String childId) async {
    final hasAssets = await _hasLinkedAssets(
      parentId: parentId,
      childId: childId,
    );

    if (hasAssets) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot delete'),
          content: const Text(
            'This subcategory is used by existing assets.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await Supabase.instance.client
        .from('categories2')
        .delete()
        .eq('id', childId);

    loadAll();
  }

  Future<bool> _hasLinkedAssets({
    required String parentId,
    String? childId,
  }) async {
    final supabase = Supabase.instance.client;

    if (childId == null) {
      final rows = await supabase
          .from('assets')
          .select('id')
          .eq('category1_id', parentId)
          .limit(1);

      return rows.isNotEmpty;
    }

    final rows = await supabase
        .from('assets')
        .select('id')
        .eq('category1_id', parentId)
        .eq('category2_id', childId)
        .limit(1);

    return rows.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: addParent,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final p in parents)
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              p['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editCategory(context, p),
                          ),
                        ],
                      ),
                      children: [
                        for (final c in children[p['id']] ?? [])
                          ListTile(
                            title: Text(c['name'] as String),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () =>
                                  deleteChild(p['id'] as String, c['id'] as String),
                            ),
                            onTap: () => _editSubCategory(
                              context,
                              c['id'] as String,
                              c['name'] as String,
                            ),
                          ),
                        ListTile(
                          leading: Icon(
                            Icons.add,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            'Add subcategory',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          onTap: () => addChild(p['id'] as String),
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          title: const Text(
                            'Delete category',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () => deleteParent(p['id'] as String),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
