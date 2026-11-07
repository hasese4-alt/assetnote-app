import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF7F5F5),
  cardColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    elevation: 0,
    foregroundColor: Colors.black87,
    centerTitle: true,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(
      color: Color(0xFF323232),
      fontSize: 16,
    ),
    bodyMedium: TextStyle(
      color: Color(0xFF323232),
      fontSize: 14,
    ),
    bodySmall: TextStyle(
      color: Color(0xFF8C8989),
      fontSize: 12,
    ),
  ),
  dividerColor: const Color(0xFFE9E7E7),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: Color(0xFF2864F0),
    unselectedItemColor: Color(0xFF8C8989),
    showSelectedLabels: true,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
    enabledBorder: OutlineInputBorder(),
    focusedBorder: OutlineInputBorder(),
  ),
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF2864F0),
    onPrimary: Colors.white,
    secondary: Color(0xFF1E46AA),
    onSecondary: Colors.white,
    error: Color(0xFFDC1E32),
    onError: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF323232),
  ),
);

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
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF2C2C2E),
    selectedItemColor: Color(0xFF5A85F0),
    unselectedItemColor: Color(0xFF8E8E93),
    showSelectedLabels: true,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
    enabledBorder: OutlineInputBorder(),
    focusedBorder: OutlineInputBorder(),
  ),
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF5A85F0),
    onPrimary: Colors.white,
    secondary: Color(0xFF3D6BE0),
    onSecondary: Colors.black,
    error: Color(0xFFDC1E32),
    onError: Colors.white,
    surface: Color(0xFF2C2C2E),
    onSurface: Colors.white,
  ),
);
