import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:asset_note/pages/assets_list_page.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,

  // 背景（Apple純正のような薄いブルーグレー）
  scaffoldBackgroundColor: const Color(0xFFF7F9FC),

  // カード（白で浮かせる）
  cardColor: Colors.white,

  // アクセントカラー（Categoryカラーと統一）
  primaryColor: Colors.blue.shade600,

  // AppBar（白背景＋影なし）
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white,
    elevation: 0,
    foregroundColor: Colors.black87,
    centerTitle: true,
  ),

  // テキスト（Appleの階層に合わせた色）
  textTheme: const TextTheme(
    bodyLarge: TextStyle(
      color: Color(0xFF1C1C1E), // メインテキスト
      fontSize: 16,
    ),
    bodyMedium: TextStyle(color: Color(0xFF1C1C1E), fontSize: 14),
    bodySmall: TextStyle(
      color: Color(0xFF6E6E73), // サブテキスト
      fontSize: 12,
    ),
  ),

  // 仕切り線（iOSの薄いグレー）
  dividerColor: const Color(0xFFE5E5EA),

  // ボタンや色の統一
  colorScheme: ColorScheme.light(
    primary: Colors.blue.shade600,
    secondary: Colors.blue.shade400,
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,

  // 背景（Apple純正の深いグレー）
  scaffoldBackgroundColor: const Color(0xFF1C1C1E),

  // カード（iOSのカード色）
  cardColor: const Color(0xFF2C2C2E),

  // アクセントカラー（ライトと同じ青600のダーク版）
  primaryColor: Colors.blue.shade400,

  // AppBar（背景と馴染ませる）
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1C1C1E),
    elevation: 0,
    foregroundColor: Colors.white,
    centerTitle: true,
  ),

  // テキスト（Appleの階層に合わせた色）
  textTheme: const TextTheme(
    bodyLarge: TextStyle(
      color: Colors.white, // メインテキスト
      fontSize: 16,
    ),
    bodyMedium: TextStyle(color: Colors.white, fontSize: 14),
    bodySmall: TextStyle(
      color: Color(0xFF8E8E93), // サブテキスト（iOSの薄いグレー）
      fontSize: 12,
    ),
  ),

  // 仕切り線（iOSのダークモード用）
  dividerColor: const Color(0xFF3A3A3C),

  // 色の統一
  colorScheme: ColorScheme.dark(
    primary: Colors.blue.shade400,
    secondary: Colors.blue.shade300,
  ),
);

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

  // ★ セッションは自動復元されるので recoverSession() は不要
  // ★ currentSession が null のときだけ匿名ログイン
  if (supabase.auth.currentSession == null) {
    await supabase.auth.signInAnonymously();
  }

  print(supabase.auth.currentUser!.id);

  runApp(const MyApp());
}

const Color category1Color = Colors.blueAccent;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AssetNote',
      theme: lightTheme,
      darkTheme: darkTheme, // ← ダークテーマは後で作る
      themeMode: ThemeMode.system, // ← 自動切替
      home: const AssetsListPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
