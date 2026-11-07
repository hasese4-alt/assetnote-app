import 'package:asset_note/pages/add_asset_page.dart';
import 'package:asset_note/pages/analysis_page.dart';
import 'package:asset_note/pages/delete_asset_page.dart';
import 'package:asset_note/pages/assets_list_page.dart';
import 'package:asset_note/pages/home_page.dart';
import 'package:asset_note/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final _homeRefreshNotifier = ValueNotifier<int>(0);
  final _listRefreshNotifier = ValueNotifier<int>(0);
  final _analysisRefreshNotifier = ValueNotifier<int>(0);
  final _hideTotalNotifier = ValueNotifier<bool>(false);
  final _addMonthNotifier = ValueNotifier<(int, int)>((DateTime.now().year, DateTime.now().month));

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadHideTotal();
    _pages = [
      HomePage(refreshNotifier: _homeRefreshNotifier, hideTotalNotifier: _hideTotalNotifier),
      AssetsListPage(refreshNotifier: _listRefreshNotifier, hideTotalNotifier: _hideTotalNotifier, addMonthNotifier: _addMonthNotifier),
      AnalysisPage(refreshNotifier: _analysisRefreshNotifier),
      const SettingsPage(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDataWarningIfNeeded());
  }

  Future<void> _loadHideTotal() async {
    final prefs = await SharedPreferences.getInstance();
    _hideTotalNotifier.value = prefs.getBool('hideTotal') ?? false;
  }

  Future<void> _showDataWarningIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('data_warning_shown') ?? false;
    if (shown || !mounted) return;

    await prefs.setBool('data_warning_shown', true);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, size: 20),
            SizedBox(width: 8),
            Text('データについてご確認ください', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        content: const Text(
          'このアプリはデバイスに紐付けてデータを保存します。\n\n'
          'アプリの削除や機種変更の前に、設定画面の「バックアップ」からデータを保存してください。',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('確認しました'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _homeRefreshNotifier.dispose();
    _listRefreshNotifier.dispose();
    _analysisRefreshNotifier.dispose();
    _hideTotalNotifier.dispose();
    _addMonthNotifier.dispose();
    super.dispose();
  }

  void _showActionMenu() {
    final (addYear, addMonth) = _addMonthNotifier.value;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
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
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Color(0xFF007AFF)),
              title: const Text('資産を追加', style: TextStyle(color: Color(0xFF007AFF))),
              subtitle: const Text('仕入・購入など'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddAssetPage(year: addYear, month: addMonth),
                  ),
                ).then((_) {
                  _homeRefreshNotifier.value++;
                  _listRefreshNotifier.value++;
                });
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.remove_circle_outline,
                color: Colors.red,
              ),
              title: const Text(
                '資産を処分',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('売却・処分など'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeleteAssetPage(
                      activeYear: addYear,
                      activeMonth: addMonth,
                    ),
                  ),
                ).then((_) {
                  _homeRefreshNotifier.value++;
                  _listRefreshNotifier.value++;
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final selectedColor =
        isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
    final unselectedColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showActionMenu,
        backgroundColor: selectedColor,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: barColor,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        height: 64,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _BottomNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'ホーム',
              selected: _currentIndex == 0,
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              onTap: () {
                if (_currentIndex != 0) _homeRefreshNotifier.value++;
                setState(() => _currentIndex = 0);
              },
            ),
            _BottomNavItem(
              icon: Icons.list_alt_outlined,
              activeIcon: Icons.list_alt,
              label: '資産一覧',
              selected: _currentIndex == 1,
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              onTap: () {
                if (_currentIndex != 1) _listRefreshNotifier.value++;
                setState(() => _currentIndex = 1);
              },
            ),
            const SizedBox(width: 80),
            _BottomNavItem(
              icon: Icons.menu_book_outlined,
              activeIcon: Icons.menu_book,
              label: '資産台帳',
              selected: _currentIndex == 2,
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              onTap: () {
                if (_currentIndex != 2) _analysisRefreshNotifier.value++;
                setState(() => _currentIndex = 2);
              },
            ),
            _BottomNavItem(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              label: '設定',
              selected: _currentIndex == 3,
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              onTap: () => setState(() => _currentIndex = 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
