import 'package:asset_note/services/assets_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CategorySettingsPage extends StatefulWidget {
  const CategorySettingsPage({super.key});

  @override
  State<CategorySettingsPage> createState() => _CategorySettingsPageState();
}

class _CategorySettingsPageState extends State<CategorySettingsPage> {
  late final AssetsRepository _repository;
  List<Map<String, dynamic>> parents = [];
  Map<String, List<Map<String, dynamic>>> children = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = AssetsRepository(Supabase.instance.client);
    loadAll();
  }

  Future<void> loadAll() async {
    setState(() => isLoading = true);
    final h = await _repository.fetchCategoryHierarchy();

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

  // ── ダイアログ ──────────────────────────────────────────────

  Future<void> _showNameDialog({
    required BuildContext context,
    required String title,
    String initialValue = '',
    required Future<void> Function(String name) onSave,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? const Color(0xFF2C2C2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Name',
            filled: true,
            fillColor: isDark
                ? const Color(0xFF3A3A3C)
                : const Color(0xFFF2F2F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'キャンセル',
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.primary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 44, color: Theme.of(ctx).dividerColor),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    await onSave(name);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    await loadAll();
                  },
                  child: Text(
                    '保存',
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirm({
    required BuildContext context,
    required String message,
    required Future<void> Function() onDelete,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF2C2C2E) : Colors.white;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Text(
                          message,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF8E8E93)
                                : const Color(0xFF6E6E73),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Divider(height: 1, color: Theme.of(ctx).dividerColor),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await onDelete();
                          if (mounted) await loadAll();
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: const Text(
                          '削除',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(
                      'キャンセル',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showBlockedDialog(BuildContext context, String message) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? const Color(0xFF2C2C2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          '削除できません',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'OK',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CRUD ────────────────────────────────────────────────────

  Future<void> _renameParent(Map<String, dynamic> p) => _showNameDialog(
        context: context,
        title: 'カテゴリ名を変更',
        initialValue: p['name'] as String,
        onSave: (name) =>
            _repository.updateCategory1(id: p['id'] as String, name: name),
      );

  Future<void> _addParent() => _showNameDialog(
        context: context,
        title: 'カテゴリを追加',
        onSave: (name) => _repository.insertCategory1(name: name),
      );

  Future<void> _deleteParent(String id) async {
    final hasAssets =
        await _repository.hasLinkedAssets(category1Id: id);
    if (!mounted) return;
    if (hasAssets) {
      await _showBlockedDialog(
          context, '資産が登録されているため\n削除できません。');
      return;
    }
    await _showDeleteConfirm(
      context: context,
      message: 'このカテゴリを削除します。\nサブカテゴリも一緒に削除されます。',
      onDelete: () => _repository.deleteCategory1(id: id),
    );
  }

  Future<void> _renameChild(String id, String oldName) => _showNameDialog(
        context: context,
        title: 'サブカテゴリ名を変更',
        initialValue: oldName,
        onSave: (name) =>
            _repository.updateCategory2(id: id, name: name),
      );

  Future<void> _addChild(String parentId) => _showNameDialog(
        context: context,
        title: 'サブカテゴリを追加',
        onSave: (name) =>
            _repository.insertCategory2(parentId: parentId, name: name),
      );

  Future<void> _deleteChild(String parentId, String childId) async {
    final hasAssets = await _repository.hasLinkedAssets(
      category1Id: parentId,
      category2Id: childId,
    );
    if (!mounted) return;
    if (hasAssets) {
      await _showBlockedDialog(
          context, '資産が登録されているため\n削除できません。');
      return;
    }
    await _showDeleteConfirm(
      context: context,
      message: 'このサブカテゴリを削除します。',
      onDelete: () => _repository.deleteCategory2(id: childId),
    );
  }

  // ── UI ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final dividerColor = Theme.of(context).dividerColor;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'カテゴリ',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _addParent,
            child: Text(
              '追加',
              style: TextStyle(
                color: primary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              children: [
                for (final p in parents) ...[
                  // ── カテゴリヘッダー ──
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 4, bottom: 6, top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p['name'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFF8E8E93)
                                  : const Color(0xFF6E6E73),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _renameParent(p),
                          child: Text(
                            '編集',
                            style: TextStyle(
                              fontSize: 13,
                              color: primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _deleteParent(p['id'] as String),
                          child: const Text(
                            '削除',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── グループコンテナ ──
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // サブカテゴリ一覧
                        for (int i = 0;
                            i < (children[p['id']] ?? []).length;
                            i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 16,
                              color: dividerColor,
                            ),
                          _SubCategoryRow(
                            name: children[p['id']]![i]['name'] as String,
                            onTap: () => _renameChild(
                              children[p['id']]![i]['id'] as String,
                              children[p['id']]![i]['name'] as String,
                            ),
                            onDelete: () => _deleteChild(
                              p['id'] as String,
                              children[p['id']]![i]['id'] as String,
                            ),
                          ),
                        ],

                        // 区切り
                        if ((children[p['id']] ?? []).isNotEmpty)
                          Divider(
                              height: 1,
                              indent: 16,
                              color: dividerColor),

                        // サブカテゴリを追加
                        InkWell(
                          onTap: () => _addChild(p['id'] as String),
                          borderRadius: BorderRadius.vertical(
                            top: (children[p['id']] ?? []).isEmpty
                                ? const Radius.circular(12)
                                : Radius.zero,
                            bottom: const Radius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(Icons.add,
                                    size: 18, color: primary),
                                const SizedBox(width: 8),
                                Text(
                                  'サブカテゴリを追加',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
    );
  }
}

class _SubCategoryRow extends StatelessWidget {
  const _SubCategoryRow({
    required this.name,
    required this.onTap,
    required this.onDelete,
  });

  final String name;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.remove_circle_outline,
                size: 20,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
