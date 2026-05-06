import 'package:asset_note/viewmodels/assets_view_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeneralSettingsPage extends StatefulWidget {
  const GeneralSettingsPage({super.key});

  @override
  State<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  int _userAge = 30;

  @override
  void initState() {
    super.initState();
    _loadAge();
  }

  Future<void> _loadAge() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _userAge = prefs.getInt('userAge') ?? 30);
  }

  Future<void> _saveAge(int age) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userAge', age);
    if (!mounted) return;
    setState(() => _userAge = age);
  }

  void _showAgePicker() {
    int tempAge = _userAge;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 280,
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'キャンセル',
                      style: TextStyle(
                        color: isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: const Text(
                      '完了',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      _saveAge(tempAge);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                  initialItem: (_userAge - 18).clamp(0, 62),
                ),
                itemExtent: 40,
                backgroundColor: isDark ? const Color(0xFF1C1C1E) : null,
                onSelectedItemChanged: (i) => tempAge = i + 18,
                children: List.generate(
                  63,
                  (i) => Center(
                    child: Text(
                      '${i + 18}歳',
                      style: TextStyle(
                        fontSize: 20,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ageGroup = AssetsViewModel.ageGroupForAge(_userAge);
    final ageGroupLabel = AssetsViewModel.ageGroupJapaneseLabel(ageGroup);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '一般設定',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 28),
          _buildSectionLabel('プロフィール'),
          const SizedBox(height: 8),
          _buildSettingsCard(
            context,
            isLight: isLight,
            child: _buildRow(
              context,
              label: '年齢',
              trailing: '$_userAge歳',
              onTap: _showAgePicker,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '同世代（$ageGroupLabel）の資産分布をもとにランクを計算します。',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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

  Widget _buildSettingsCard(
    BuildContext context, {
    required bool isLight,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required String label,
    required String trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            Row(
              children: [
                Text(
                  trailing,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
