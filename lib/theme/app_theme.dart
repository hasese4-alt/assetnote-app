import 'package:flutter/material.dart';
import 'package:asset_note/theme/app_tokens.dart';

export 'package:asset_note/theme/app_tokens.dart';

ThemeData _buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.accent,
    onSecondary: c.onAccent,
    error: c.destructive,
    onError: Colors.white,
    surface: c.surface,
    onSurface: c.label,
    onSurfaceVariant: c.secondaryLabel,
    outline: c.opaqueSeparator,
    outlineVariant: c.separator,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    extensions: [c],
    scaffoldBackgroundColor: c.background,
    cardColor: c.surface,
    dividerColor: c.separator,
    dividerTheme: DividerThemeData(color: c.separator, thickness: 0.5, space: 0.5),
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: c.label,
      centerTitle: true,
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: c.label, fontSize: AppFont.callout),
      // 14 は iOS の段階に無いが、既存画面のレイアウト崩れを避けるため据え置き
      bodyMedium: TextStyle(color: c.label, fontSize: 14),
      bodySmall: TextStyle(color: c.secondaryLabel, fontSize: AppFont.caption1),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: c.surface,
      selectedItemColor: c.accent,
      unselectedItemColor: c.secondaryLabel,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
      enabledBorder: OutlineInputBorder(borderRadius: AppRadius.mdAll),
      focusedBorder: OutlineInputBorder(borderRadius: AppRadius.mdAll),
    ),
  );
}

final ThemeData lightTheme = _buildTheme(Brightness.light);
final ThemeData darkTheme = _buildTheme(Brightness.dark);
