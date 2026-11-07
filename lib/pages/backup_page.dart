import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:asset_note/services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  late final BackupService _backupService;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _backupService = BackupService(Supabase.instance.client);
  }

  // ─────────────────────── BACKUP ───────────────────────

  Future<void> _runBackup() async {
    setState(() => _isProcessing = true);
    try {
      await _backupService.runBackup();
    } on BackupValidationException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('バックアップに失敗しました。\n$e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─────────────────────── RESTORE ───────────────────────

  Future<void> _runRestore() async {
    // Step 1: ファイル選択
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      _showError('ファイルの読み込みに失敗しました');
      return;
    }

    final content = utf8.decode(bytes);

    // Step 2: バリデーション
    Map<String, dynamic> parsed;
    try {
      parsed = _backupService.validateBackupJson(content);
    } on BackupValidationException catch (e) {
      _showError('無効なバックアップファイルです。\n${e.message}');
      return;
    }

    // Step 3: 確認ダイアログ
    final confirmed = await _showRestoreDialog(parsed['exported_at'] as String?);
    if (!confirmed) return;

    // Step 4: 復元実行
    setState(() => _isProcessing = true);
    try {
      await _backupService.runRestore(content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('復元が完了しました')),
        );
      }
    } catch (e) {
      _showError('復元に失敗しました。バックアップファイルから再度お試しください。\n$e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<bool> _showRestoreDialog(String? exportedAt) async {
    String dateLabel = '';
    if (exportedAt != null) {
      try {
        final dt = DateTime.parse(exportedAt).toLocal();
        dateLabel =
            '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('データを復元しますか？'),
        content: Text(
          '現在のすべてのデータは削除され、'
          'バックアップ${dateLabel.isNotEmpty ? '（$dateLabel）' : ''}'
          'のデータに置き換えられます。\nこの操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC1E32),
            ),
            child: const Text('復元する'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // ─────────────────────── BUILD ───────────────────────

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFF000000),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: false,
            floating: true,
            snap: true,
            title: Text(
              'データ管理',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge!
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
            sliver: SliverToBoxAdapter(
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel(context, 'バックアップ・復元'),
                      const SizedBox(height: 8),
                      _card(
                        context,
                        isLight: isLight,
                        children: [
                          _row(
                            context,
                            icon: Icons.download_outlined,
                            label: 'バックアップ',
                            sublabel: 'データをJSONファイルとして書き出す',
                            onTap: _isProcessing ? null : _runBackup,
                          ),
                          Divider(
                            height: 1,
                            indent: 52,
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.15),
                          ),
                          _row(
                            context,
                            icon: Icons.upload_outlined,
                            label: '復元',
                            sublabel: 'バックアップファイルからデータを復元する',
                            onTap: _isProcessing ? null : _runRestore,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          '復元を実行すると現在のすべてのデータが削除され、バックアップのデータに置き換えられます。',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isProcessing)
                    Positioned.fill(
                      child: Container(
                        color: Theme.of(context)
                            .scaffoldBackgroundColor
                            .withValues(alpha: 0.6),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required bool isLight,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? sublabel,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade500),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16)),
                  if (sublabel != null)
                    Text(
                      sublabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
