import 'package:asset_note/theme/app_tokens.dart';
import 'package:asset_note/services/assets_repository.dart';
import 'package:asset_note/utils/category_favicon.dart';
import 'package:asset_note/viewmodels/assets_view_model.dart';
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
    final results = await Future.wait([
      _repository.fetchCategoryHierarchy(),
      _repository.fetchCurrentAssets(),
    ]);
    final h = results[0] as ({
      List<Map<String, dynamic>> parentCategories,
      Map<String, List<Map<String, dynamic>>> childCategories,
    });
    final assets = results[1] as List<Map<String, dynamic>>;

    // ホーム画面と同じ順序（資産合計金額の降順）でカテゴリをソート
    final grouped = AssetsViewModel.groupForDisplay(assets);
    final orderedIds = grouped.keys.toList();
    final sortedParents = [
      ...orderedIds
          .map((id) => h.parentCategories.firstWhere(
                (p) => p['id'] == id,
                orElse: () => <String, dynamic>{},
              ))
          .where((p) => p.isNotEmpty),
      ...h.parentCategories.where((p) => !orderedIds.contains(p['id'])),
    ];

    final map = <String, List<Map<String, dynamic>>>{};
    for (final p in sortedParents) {
      final pid = p['id'] as String;
      final allChildren = List<Map<String, dynamic>>.from(h.childCategories[pid] ?? []);
      final orderedC2Ids = grouped[pid]?.keys.toList() ?? [];
      map[pid] = [
        ...orderedC2Ids
            .map((id) => allChildren.firstWhere(
                  (c) => c['id'] == id,
                  orElse: () => <String, dynamic>{},
                ))
            .where((c) => c.isNotEmpty),
        ...allChildren.where((c) => !orderedC2Ids.contains(c['id'])),
      ];
    }

    setState(() {
      parents = sortedParents;
      children = map;
      isLoading = false;
    });
  }

  // ── ダイアログ ──────────────────────────────────────────────

  Future<({String name, String? icon})?> _showParentCategoryDialog({
    required String title,
    String initialName = '',
    String? initialIconKey,
  }) {
    return showDialog<({String name, String? icon})>(
      context: context,
      builder: (ctx) => _ParentCategoryDialog(
        title: title,
        initialName: initialName,
        initialIconKey: initialIconKey,
      ),
    );
  }

  Future<void> _showNameDialog({
    required BuildContext context,
    required String title,
    String initialValue = '',
    bool initialHideFavicon = false,
    required Future<void> Function(String name, bool hideFavicon) onSave,
  }) async {
    final controller = TextEditingController(text: initialValue);
    String previewName = initialValue;
    bool hideFavicon = initialHideFavicon;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final faviconUrl = faviconUrlForCategoryLabel(previewName);
          final primary = Theme.of(ctx).colorScheme.primary;
          return AlertDialog(
            backgroundColor: context.colors.surface,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
            title: Text(
              title,
              style: const TextStyle(fontSize: AppFont.body, fontWeight: AppFont.semibold),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (v) => setState(() {
                    previewName = v;
                    hideFavicon = false;
                  }),
                  style: const TextStyle(fontSize: AppFont.callout),
                  decoration: InputDecoration(
                    hintText: 'Name',
                    filled: true,
                    fillColor: context.colors.fill,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                if (faviconUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Opacity(
                          opacity: hideFavicon ? 0.3 : 1.0,
                          child: Image.network(
                            faviconUrl,
                            width: 20,
                            height: 20,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'アイコンを使用',
                            style: TextStyle(
                              fontSize: AppFont.footnote,
                              color: context.colors.label,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: !hideFavicon,
                          activeTrackColor: primary,
                          onChanged: (v) => setState(() => hideFavicon = !v),
                        ),
                      ],
                    ),
                  ),
              ],
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
                          color: primary,
                          fontSize: AppFont.callout,
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
                        await onSave(name, hideFavicon);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await loadAll();
                      },
                      child: Text(
                        '保存',
                        style: TextStyle(
                          color: primary,
                          fontWeight: AppFont.semibold,
                          fontSize: AppFont.callout,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
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
        final bg = context.colors.surface;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: AppRadius.lgAll,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Text(
                          message,
                          style: TextStyle(
                            fontSize: AppFont.footnote,
                            color: context.colors.secondaryLabel,
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
                        child: Text(
                          '削除',
                          style: TextStyle(
                            color: context.colors.destructive,
                            fontSize: AppFont.body,
                            fontWeight: AppFont.regular,
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
                    borderRadius: AppRadius.lgAll,
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
                        fontWeight: AppFont.semibold,
                        fontSize: AppFont.body,
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
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Text(
          '削除できません',
          style: TextStyle(fontSize: AppFont.body, fontWeight: AppFont.semibold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: AppFont.subheadline),
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
                fontWeight: AppFont.semibold,
                fontSize: AppFont.callout,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CRUD ────────────────────────────────────────────────────

  Future<void> _renameParent(Map<String, dynamic> p) async {
    final result = await _showParentCategoryDialog(
      title: 'カテゴリを編集',
      initialName: p['name'] as String,
      initialIconKey: p['icon'] as String?,
    );
    if (result == null) return;
    await _repository.updateCategory1(
      id: p['id'] as String,
      name: result.name,
      icon: result.icon,
    );
    await loadAll();
  }

  Future<void> _addParent() async {
    final result = await _showParentCategoryDialog(
      title: 'カテゴリを追加',
    );
    if (result == null) return;
    await _repository.insertCategory1(name: result.name, icon: result.icon);
    await loadAll();
  }

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

  Future<void> _renameChild(Map<String, dynamic> child) => _showNameDialog(
        context: context,
        title: 'サブカテゴリ名を変更',
        initialValue: child['name'] as String,
        initialHideFavicon: child['hide_favicon'] as bool? ?? false,
        onSave: (name, hideFavicon) => _repository.updateCategory2(
          id: child['id'] as String,
          name: name,
          hideFavicon: hideFavicon,
        ),
      );

  Future<void> _addChild(String parentId) => _showNameDialog(
        context: context,
        title: 'サブカテゴリを追加',
        onSave: (name, hideFavicon) => _repository.insertCategory2(
          parentId: parentId,
          name: name,
          hideFavicon: hideFavicon,
        ),
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
    final cardColor =
        context.colors.surface;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'カテゴリ',
          style: TextStyle(fontSize: AppFont.body, fontWeight: AppFont.semibold),
        ),
        actions: [
          TextButton(
            onPressed: _addParent,
            child: Text(
              '追加',
              style: TextStyle(
                color: primary,
                fontSize: AppFont.callout,
                fontWeight: AppFont.medium,
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
                        if (categoryIconDataForKey(p['icon'] as String?) != null) ...[
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.12),
                              borderRadius: AppRadius.smAll,
                            ),
                            child: Icon(
                              categoryIconDataForKey(p['icon'] as String?),
                              size: 13,
                              color: primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            p['name'] as String,
                            style: TextStyle(
                              fontSize: AppFont.footnote,
                              fontWeight: AppFont.medium,
                              color: context.colors.secondaryLabel,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _renameParent(p),
                          child: Text(
                            '編集',
                            style: TextStyle(
                              fontSize: AppFont.footnote,
                              color: primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _deleteParent(p['id'] as String),
                          child: Text(
                            '削除',
                            style: TextStyle(
                              fontSize: AppFont.footnote,
                              color: context.colors.destructive,
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
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(
                        color: context.colors.separator,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // サブカテゴリ一覧
                        for (final child in (children[p['id']] ?? []))
                          _SubCategoryRow(
                            name: child['name'] as String,
                            hideFavicon: child['hide_favicon'] as bool? ?? false,
                            onTap: () => _renameChild(child),
                            onDelete: () => _deleteChild(
                              p['id'] as String,
                              child['id'] as String,
                            ),
                          ),

                        // サブカテゴリを追加
                        InkWell(
                          onTap: () => _addChild(p['id'] as String),
                          borderRadius: BorderRadius.vertical(
                            top: (children[p['id']] ?? []).isEmpty
                                ? const Radius.circular(AppRadius.md)
                                : Radius.zero,
                            bottom: const Radius.circular(AppRadius.md),
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
                                    fontSize: AppFont.subheadline,
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

// ── アイコン選択ボトムシート ────────────────────────────────────

Future<String?> showIconPickerSheet(BuildContext context, String? currentKey) {
  return showModalBottomSheet<String?>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final primary = Theme.of(ctx).colorScheme.primary;
      return SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.background,
            borderRadius: AppRadius.sheetTop,
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.opaqueSeparator,
                  borderRadius: AppRadius.grabberAll,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'アイコンを選択',
                style: TextStyle(fontSize: AppFont.body, fontWeight: AppFont.semibold),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  // なし（クリア）
                  _IconPickerCell(
                    isSelected: currentKey == null || currentKey.isEmpty,
                    onTap: () => Navigator.pop(ctx, ''),
                    label: 'なし',
                    primary: primary,
                    isDark: isDark,
                    child: Icon(
                      Icons.remove_circle_outline,
                      size: 26,
                      color: context.colors.secondaryLabel,
                    ),
                  ),
                  ...kCategoryIcons.map(
                    (def) => _IconPickerCell(
                      isSelected: currentKey == def.key,
                      onTap: () => Navigator.pop(ctx, def.key),
                      label: def.label,
                      primary: primary,
                      isDark: isDark,
                      child: Icon(def.data, size: 26),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

class _IconPickerCell extends StatelessWidget {
  const _IconPickerCell({
    required this.isSelected,
    required this.onTap,
    required this.label,
    required this.child,
    required this.primary,
    required this.isDark,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final String label;
  final Widget child;
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.15)
              : (context.colors.surface),
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: isSelected ? primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            child,
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: AppFont.caption2),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 親カテゴリ編集ダイアログ ────────────────────────────────────

class _ParentCategoryDialog extends StatefulWidget {
  const _ParentCategoryDialog({
    required this.title,
    required this.initialName,
    required this.initialIconKey,
  });

  final String title;
  final String initialName;
  final String? initialIconKey;

  @override
  State<_ParentCategoryDialog> createState() => _ParentCategoryDialogState();
}

class _ParentCategoryDialogState extends State<_ParentCategoryDialog> {
  late final TextEditingController _nameCtrl;
  String? _iconKey;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _iconKey = widget.initialIconKey;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    FocusScope.of(context).unfocus();
    final result = await showIconPickerSheet(context, _iconKey);
    if (result == null) return; // dismissed
    setState(() => _iconKey = result.isEmpty ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final iconData = categoryIconDataForKey(_iconKey);

    return AlertDialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: AppFont.body, fontWeight: AppFont.semibold),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            style: const TextStyle(fontSize: AppFont.callout),
            decoration: InputDecoration(
              hintText: '名前',
              filled: true,
              fillColor:
                  context.colors.fill,
              border: OutlineInputBorder(
                borderRadius: AppRadius.mdAll,
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickIcon,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: context.colors.fill,
                borderRadius: AppRadius.mdAll,
              ),
              child: Row(
                children: [
                  Text(
                    'アイコン',
                    style: TextStyle(
                      fontSize: AppFont.subheadline,
                      color: context.colors.label,
                    ),
                  ),
                  const Spacer(),
                  if (iconData != null)
                    Icon(iconData, size: 22, color: primary)
                  else
                    Text(
                      '選択',
                      style: TextStyle(fontSize: AppFont.subheadline, color: primary),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: context.colors.tertiaryLabel,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actionsPadding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'キャンセル',
                  style: TextStyle(color: primary, fontSize: AppFont.callout),
                ),
              ),
            ),
            Container(
                width: 1, height: 44, color: Theme.of(context).dividerColor),
            Expanded(
              child: TextButton(
                onPressed: () {
                  final name = _nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(context, (name: name, icon: _iconKey));
                },
                child: Text(
                  '保存',
                  style: TextStyle(
                    color: primary,
                    fontWeight: AppFont.semibold,
                    fontSize: AppFont.callout,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SubCategoryRow extends StatelessWidget {
  const _SubCategoryRow({
    required this.name,
    required this.hideFavicon,
    required this.onTap,
    required this.onDelete,
  });

  final String name;
  final bool hideFavicon;
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
              child: hideFavicon
                  ? Text(name, style: const TextStyle(fontSize: AppFont.subheadline))
                  : categoryTitleWithOptionalFavicon(
                      label: name,
                      style: const TextStyle(fontSize: AppFont.subheadline),
                      iconSize: 16,
                    ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                Icons.remove_circle_outline,
                size: 20,
                color: context.colors.destructive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
