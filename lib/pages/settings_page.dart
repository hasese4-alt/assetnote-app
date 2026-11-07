import 'package:asset_note/pages/backup_page.dart';
import 'package:asset_note/pages/category_settings_page.dart';
import 'package:asset_note/pages/privacy_policy_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kFiscalStartMonth = 'fiscalYearStartMonth';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _fiscalStartMonth = 1;

  @override
  void initState() {
    super.initState();
    _loadFiscalStartMonth();
  }

  Future<void> _loadFiscalStartMonth() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _fiscalStartMonth = prefs.getInt(_kFiscalStartMonth) ?? 1);
    }
  }

  Future<void> _saveFiscalStartMonth(int month) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFiscalStartMonth, month);
    if (mounted) setState(() => _fiscalStartMonth = month);
  }

  void _showFiscalMonthPicker() {
    int tempMonth = _fiscalStartMonth;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '期首月を選択',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    TextButton(
                      onPressed: () {
                        _saveFiscalStartMonth(tempMonth);
                        Navigator.pop(ctx);
                      },
                      child: const Text('完了'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 200,
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: _fiscalStartMonth - 1,
                  ),
                  itemExtent: 36,
                  onSelectedItemChanged: (i) => tempMonth = i + 1,
                  children: List.generate(
                    12,
                    (i) => Center(child: Text('${i + 1}月')),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

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
            centerTitle: false,
            title: Text(
              '設定',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel(context, 'カスタマイズ'),
                  const SizedBox(height: 8),
                  _card(
                    context,
                    isLight: isLight,
                    children: [
                      _row(
                        context,
                        icon: Icons.category_outlined,
                        label: 'カテゴリ設定',
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CategorySettingsPage(),
                          ),
                        ),
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
                        icon: Icons.calendar_today_outlined,
                        label: '期首月',
                        trailing: Text(
                          '$_fiscalStartMonth月',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        onTap: _showFiscalMonthPicker,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel(context, 'アプリについて'),
                  const SizedBox(height: 8),
                  _card(
                    context,
                    isLight: isLight,
                    children: [
                      _row(
                        context,
                        icon: Icons.privacy_tip_outlined,
                        label: 'プライバシーポリシー',
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel(context, 'データ管理'),
                  const SizedBox(height: 8),
                  _card(
                    context,
                    isLight: isLight,
                    children: [
                      _row(
                        context,
                        icon: Icons.download_outlined,
                        label: 'バックアップ',
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BackupPage(),
                          ),
                        ),
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
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BackupPage(),
                          ),
                        ),
                      ),
                    ],
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
      padding: const EdgeInsets.only(left: 4, bottom: 0),
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
    required VoidCallback onTap,
    Widget? trailing,
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
              child: Text(label, style: const TextStyle(fontSize: 16)),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 4),
            ],
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
