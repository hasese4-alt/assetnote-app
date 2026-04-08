import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:asset_note/pages/assets_list_page.dart';

/// ------------------------------
/// Apple風ライトテーマ
/// ------------------------------
final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,

  // Apple純正の背景色
  scaffoldBackgroundColor: const Color(0xFFF7F9FC),

  // カード（白）
  cardColor: Colors.white,

  // AppBar（白背景＋影なし）
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    elevation: 0,
    foregroundColor: Colors.black87,
    centerTitle: true,
  ),

  // テキスト
  textTheme: const TextTheme(
    bodyLarge: TextStyle(
      color: Color(0xFF1C1C1E),
      fontSize: 16,
    ),
    bodyMedium: TextStyle(
      color: Color(0xFF1C1C1E),
      fontSize: 14,
    ),
    bodySmall: TextStyle(
      color: Color(0xFF6E6E73),
      fontSize: 12,
    ),
  ),

  dividerColor: const Color(0xFFE5E5EA),

  // ★ Apple風 ColorScheme（完全定義）
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF007AFF),
    onPrimary: Colors.white,
    secondary: Color(0xFF5AC8FA),
    onSecondary: Colors.white,
    error: Colors.red,
    onError: Colors.white,
    background: Color(0xFFF7F9FC), // ← 背景
    onBackground: Color(0xFF1C1C1E),
    surface: Colors.white, // ← カード色（最重要）
    onSurface: Color(0xFF1C1C1E),
  ),
);

/// ------------------------------
/// Apple風ダークテーマ
/// ------------------------------
final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,

  // Apple純正の深い黒背景
  scaffoldBackgroundColor: const Color(0xFF1C1C1E),

  // カード（iOSのダークカード）
  cardColor: const Color(0xFF2C2C2E),

  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1C1C1E),
    elevation: 0,
    foregroundColor: Colors.white,
    centerTitle: true,
  ),

  textTheme: const TextTheme(
    bodyLarge: TextStyle(
      color: Colors.white,
      fontSize: 16,
    ),
    bodyMedium: TextStyle(
      color: Colors.white,
      fontSize: 14,
    ),
    bodySmall: TextStyle(
      color: Color(0xFF8E8E93),
      fontSize: 12,
    ),
  ),

  dividerColor: const Color(0xFF3A3A3C),

  // ★ Apple風 ColorScheme（完全定義）
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF0A84FF),
    onPrimary: Colors.white,
    secondary: Color(0xFF64D2FF),
    onSecondary: Colors.black,
    error: Colors.red,
    onError: Colors.white,
    background: Color(0xFF1C1C1E), // ← 背景
    onBackground: Colors.white,
    surface: Color(0xFF2C2C2E), // ← カード色（最重要）
    onSurface: Colors.white,
  ),
);

/// ------------------------------
/// Supabase 初期化 & アプリ起動
/// ------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception(
      'SUPABASE_URL / SUPABASE_ANON_KEY is not set. '
      'Run with --dart-define=SUPABASE_URL=... '
      '--dart-define=SUPABASE_ANON_KEY=...',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final supabase = Supabase.instance.client;

  // セッション自動復元 → 無ければ匿名ログイン
  if (supabase.auth.currentSession == null) {
    await supabase.auth.signInAnonymously();
  }

  print(supabase.auth.currentUser!.id);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AssetNote',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system, // 自動切替
      home: const AssetsListPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}