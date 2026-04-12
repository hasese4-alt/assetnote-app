import 'package:flutter/material.dart';

/// Apple 風ライトテーマ（Material 3、`ColorScheme.surface` ベース）。
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF7F9FC),
  cardColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    elevation: 0,
    foregroundColor: Colors.black87,
    centerTitle: true,
  ),
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
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
    enabledBorder: OutlineInputBorder(),
    focusedBorder: OutlineInputBorder(),
  ),
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF007AFF),
    onPrimary: Colors.white,
    secondary: Color(0xFF5AC8FA),
    onSecondary: Colors.white,
    error: Colors.red,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF1C1C1E),
  ),
);

/// Apple 風ダークテーマ。
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF1C1C1E),
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
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
    enabledBorder: OutlineInputBorder(),
    focusedBorder: OutlineInputBorder(),
  ),
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF0A84FF),
    onPrimary: Colors.white,
    secondary: Color(0xFF64D2FF),
    onSecondary: Colors.black,
    error: Colors.red,
    onError: Colors.white,
    surface: Color(0xFF2C2C2E),
    onSurface: Colors.white,
  ),
);
