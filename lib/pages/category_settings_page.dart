import 'package:flutter/cupertino.dart';
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

  // ------------------------------------------------------------
  // 親カテゴリ rename
  // ------------------------------------------------------------
  void _editCategory(
    BuildContext context,
    Map<String, dynamic> category,
  ) async {
    final controller = TextEditingController(text: category['name']);

    await showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Rename Category'),
        content: CupertinoTextField(
          controller: controller,
          placeholder: 'New name',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Save'),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await Supabase.instance.client
                    .from('categories1')
                    .update({'name': newName})
                    .eq('id', category['id']);

                Navigator.pop(context);
                await loadAll();
              }
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // 子カテゴリ rename（ID ベース）
  // ------------------------------------------------------------
  Future<void> _editSubCategory(
    BuildContext context,
    String childId,
    String oldName,
  ) async {
    final controller = TextEditingController(text: oldName);

    await showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Rename Subcategory'),
        content: CupertinoTextField(
          controller: controller,
          placeholder: 'New name',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Save'),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await Supabase.instance.client
                    .from('categories2')
                    .update({'name': newName})
                    .eq('id', childId);

                Navigator.pop(context);
                await loadAll();
              }
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // DB 読み込み（ID + name の構造に統一）
  // ------------------------------------------------------------
  Future<void> loadAll() async {
    setState(() => isLoading = true);

    final supabase = Supabase.instance.client;

    final parentRows = await supabase
        .from('categories1')
        .select('id, name')
        .eq('user_id', userId);

    final childRows = await supabase
        .from('categories2')
        .select('id, parent_id, name')
        .eq('user_id', userId);

    final map = <String, List<Map<String, dynamic>>>{};

    for (final p in parentRows) {
      map[p['id']] = [];
    }

    for (final c in childRows) {
      map[c['parent_id']]?.add({'id': c['id'], 'name': c['name']});
    }

    setState(() {
      parents = List<Map<String, dynamic>>.from(parentRows);
      children = map;
      isLoading = false;
    });
  }

  // ------------------------------------------------------------
  // 親カテゴリ追加
  // ------------------------------------------------------------
  Future<void> addParent() async {
    final controller = TextEditingController();

    await showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Add Category'),
        content: CupertinoTextField(
          controller: controller,
          placeholder: 'Category name',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('Add'),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await Supabase.instance.client.from('categories1').insert({
                  'user_id': userId,
                  'name': name,
                });
                Navigator.pop(context);
                loadAll();
              }
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // 子カテゴリ追加
  // ------------------------------------------------------------
  Future<void> addChild(String parentId) async {
    final controller = TextEditingController();

    await showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Add Subcategory'),
        content: CupertinoTextField(
          controller: controller,
          placeholder: 'Subcategory name',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('Add'),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await Supabase.instance.client.from('categories2').insert({
                  'user_id': userId,
                  'parent_id': parentId,
                  'name': name,
                });
                Navigator.pop(context);
                loadAll();
              }
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // 親カテゴリ削除（ID ベース）
  // ------------------------------------------------------------
  Future<void> deleteParent(String id) async {
    final hasAssets = await _hasLinkedAssets(parentId: id);

    if (hasAssets) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Cannot delete'),
          content: const Text('This category is used by existing assets.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    await Supabase.instance.client.from('categories1').delete().eq('id', id);
    loadAll();
  }

  // ------------------------------------------------------------
  // 子カテゴリ削除（ID ベース）
  // ------------------------------------------------------------
  Future<void> deleteChild(String parentId, String childId) async {
    final hasAssets = await _hasLinkedAssets(
      parentId: parentId,
      childId: childId,
    );

    if (hasAssets) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Cannot delete'),
          content: const Text('This subcategory is used by existing assets.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
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

  // ------------------------------------------------------------
  // 削除チェック（ID ベース）
  // ------------------------------------------------------------
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
    } else {
      final rows = await supabase
          .from('assets')
          .select('id')
          .eq('category1_id', parentId)
          .eq('category2_id', childId)
          .limit(1);

      return rows.isNotEmpty;
    }
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Categories'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add),
          onPressed: addParent,
        ),
      ),
      child: SafeArea(
        child: isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                children: [
                  for (final p in parents)
                    CupertinoListSection.insetGrouped(
                      header: GestureDetector(
                        onTap: () => _editCategory(context, p),
                        child: Text(
                          p['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      children: [
                        // 子カテゴリ一覧
                        for (final c in children[p['id']]!)
                          CupertinoListTile(
                            title: Text(c['name']),
                            onTap: () =>
                                _editSubCategory(context, c['id'], c['name']),
                            trailing: CupertinoButton(
                              padding: EdgeInsets.zero,
                              child: const Icon(
                                CupertinoIcons.delete,
                                color: CupertinoColors.systemRed,
                              ),
                              onPressed: () => deleteChild(p['id'], c['id']),
                            ),
                          ),

                        // 子カテゴリ追加
                        CupertinoListTile(
                          title: const Text(
                            'Add subcategory',
                            style: TextStyle(color: CupertinoColors.activeBlue),
                          ),
                          onTap: () => addChild(p['id']),
                        ),

                        // 親カテゴリ削除
                        CupertinoListTile(
                          title: const Text(
                            'Delete category',
                            style: TextStyle(color: CupertinoColors.systemRed),
                          ),
                          onTap: () => deleteParent(p['id']),
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}
