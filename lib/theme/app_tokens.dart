import 'package:flutter/material.dart';

/// AssetNote デザイントークン
///
/// 色・文字・角丸・余白の「唯一の正解」をここに集約する。
/// 画面側では `Color(0xFF...)` や `Colors.green` を直接書かず、
/// `context.colors.xxx` / `AppFont.xxx` / `AppRadius.xxx` / `AppSpacing.xxx` を使う。
///
/// 色は iOS のシステムカラーに準拠（ライト / ダーク両対応）。

// ─────────────────────────────────────────────
// Colors
// ─────────────────────────────────────────────

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.groupedBackground,
    required this.surface,
    required this.groupedSurface,
    required this.surfaceSecondary,
    required this.fill,
    required this.separator,
    required this.opaqueSeparator,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.accent,
    required this.onAccent,
    required this.positive,
    required this.negative,
    required this.destructive,
    required this.warning,
    required this.info,
    required this.shadow,
  });

  /// 通常画面の背景（ホーム・一覧など）
  final Color background;

  /// 設定系（グループ化リスト）画面の背景
  final Color groupedBackground;

  /// background の上に置くカード
  final Color surface;

  /// groupedBackground の上に置くカード（設定のセル）
  final Color groupedSurface;

  /// シート内のカード・売却済み行など、一段沈んだ面
  final Color surfaceSecondary;

  /// カード内の入力欄・チップなどの塗り
  final Color fill;

  /// 区切り線
  final Color separator;

  /// シートのつまみ・枠線など、はっきり見せたい線
  final Color opaqueSeparator;

  /// 本文
  final Color label;

  /// 補足テキスト・未選択アイコン
  final Color secondaryLabel;

  /// プレースホルダー・矢印アイコン
  final Color tertiaryLabel;

  /// メインカラー（青）
  final Color accent;

  /// accent の上に乗せる文字・アイコン
  final Color onAccent;

  /// 増加・利益（文字で読める濃さ）
  final Color positive;

  /// 減少・損失（文字で読める濃さ）
  final Color negative;

  /// 削除などの破壊的操作
  final Color destructive;

  /// 注意・未確定
  final Color warning;

  /// 補助的な状態表示（振替など）
  final Color info;

  /// カードの影
  final Color shadow;

  /// 増減の値に応じた色（0 は positive 扱い）
  Color diff(num value) => value >= 0 ? positive : negative;

  static const light = AppColors(
    background: Color(0xFFF2F2F7),
    groupedBackground: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    groupedSurface: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFF2F2F7),
    fill: Color(0xFFF2F2F7),
    separator: Color(0xFFE5E5EA),
    opaqueSeparator: Color(0xFFD1D1D6),
    label: Color(0xFF1C1C1E),
    secondaryLabel: Color(0xFF6E6E73),
    tertiaryLabel: Color(0xFFAEAEB2),
    accent: Color(0xFF007AFF),
    onAccent: Color(0xFFFFFFFF),
    // 白背景で文字として読めるよう、iOS の高コントラスト版を採用
    positive: Color(0xFF248A3D),
    negative: Color(0xFFD70015),
    destructive: Color(0xFFFF3B30),
    warning: Color(0xFFC93400),
    info: Color(0xFF0071A4),
    shadow: Color(0x0F000000),
  );

  static const dark = AppColors(
    background: Color(0xFF1C1C1E),
    groupedBackground: Color(0xFF000000),
    surface: Color(0xFF2C2C2E),
    groupedSurface: Color(0xFF1C1C1E),
    surfaceSecondary: Color(0xFF2C2C2E),
    fill: Color(0xFF3A3A3C),
    separator: Color(0xFF3A3A3C),
    opaqueSeparator: Color(0xFF48484A),
    label: Color(0xFFFFFFFF),
    secondaryLabel: Color(0xFF8E8E93),
    tertiaryLabel: Color(0xFF636366),
    accent: Color(0xFF0A84FF),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF30D158),
    negative: Color(0xFFFF453A),
    destructive: Color(0xFFFF453A),
    warning: Color(0xFFFF9F0A),
    info: Color(0xFF64D2FF),
    shadow: Color(0x00000000),
  );

  /// グラフのカテゴリ色（ホームの円グラフ・分析の棒グラフで共通）
  ///
  /// 増減の緑・赤と見分けられるよう、緑系・赤系はあえて含めない。
  static const chartPalette = <Color>[
    Color(0xFF007AFF), // Blue
    Color(0xFFFF9F0A), // Orange
    Color(0xFF5856D6), // Indigo
    Color(0xFF64D2FF), // Cyan
    Color(0xFFAF52DE), // Purple
    Color(0xFFFFD60A), // Yellow
    Color(0xFFA2845E), // Brown
    Color(0xFF8E8E93), // Gray
  ];

  @override
  AppColors copyWith({
    Color? background,
    Color? groupedBackground,
    Color? surface,
    Color? groupedSurface,
    Color? surfaceSecondary,
    Color? fill,
    Color? separator,
    Color? opaqueSeparator,
    Color? label,
    Color? secondaryLabel,
    Color? tertiaryLabel,
    Color? accent,
    Color? onAccent,
    Color? positive,
    Color? negative,
    Color? destructive,
    Color? warning,
    Color? info,
    Color? shadow,
  }) {
    return AppColors(
      background: background ?? this.background,
      groupedBackground: groupedBackground ?? this.groupedBackground,
      surface: surface ?? this.surface,
      groupedSurface: groupedSurface ?? this.groupedSurface,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      fill: fill ?? this.fill,
      separator: separator ?? this.separator,
      opaqueSeparator: opaqueSeparator ?? this.opaqueSeparator,
      label: label ?? this.label,
      secondaryLabel: secondaryLabel ?? this.secondaryLabel,
      tertiaryLabel: tertiaryLabel ?? this.tertiaryLabel,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      destructive: destructive ?? this.destructive,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      groupedBackground: l(groupedBackground, other.groupedBackground),
      surface: l(surface, other.surface),
      groupedSurface: l(groupedSurface, other.groupedSurface),
      surfaceSecondary: l(surfaceSecondary, other.surfaceSecondary),
      fill: l(fill, other.fill),
      separator: l(separator, other.separator),
      opaqueSeparator: l(opaqueSeparator, other.opaqueSeparator),
      label: l(label, other.label),
      secondaryLabel: l(secondaryLabel, other.secondaryLabel),
      tertiaryLabel: l(tertiaryLabel, other.tertiaryLabel),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      positive: l(positive, other.positive),
      negative: l(negative, other.negative),
      destructive: l(destructive, other.destructive),
      warning: l(warning, other.warning),
      info: l(info, other.info),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension AppColorsX on BuildContext {
  /// `context.colors.accent` のように使う
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light);
}

// ─────────────────────────────────────────────
// Typography（iOS Human Interface Guidelines のサイズ段階）
// ─────────────────────────────────────────────

abstract final class AppFont {
  static const double largeTitle = 34;
  static const double title1 = 28;
  static const double title2 = 22;
  static const double title3 = 20;
  static const double headline = 17;
  static const double body = 17;
  static const double callout = 16;
  static const double subheadline = 15;
  static const double footnote = 13;
  static const double caption1 = 12;
  static const double caption2 = 11;

  /// 太字は最小限：通常 / 強調 / 数字の主役 の3段階のみ
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  /// アイコン内の文字（カテゴリアイコンの頭文字など）専用
  static const FontWeight heavy = FontWeight.w900;

  /// 金額表示用：桁幅が揃い、月切り替え時に数字がガタつかない
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
}

// ─────────────────────────────────────────────
// Radius
// ─────────────────────────────────────────────

abstract final class AppRadius {
  /// 極小バッジ（「売却済」など）
  static const double xs = 4;

  /// チップ・アイコン・小さなボタン
  static const double sm = 8;

  /// 行・入力欄・ボタン
  static const double md = 12;

  /// カード・シート
  static const double lg = 16;

  /// シートのつまみ・インジケーター
  static const double grabber = 2;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));

  /// 両端が丸いチップ・ボタン
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(999));

  /// シートのつまみ・凡例の小さな四角
  static const BorderRadius grabberAll =
      BorderRadius.all(Radius.circular(grabber));

  /// ボトムシート上端
  static const BorderRadius sheetTop =
      BorderRadius.vertical(top: Radius.circular(lg));
}

// ─────────────────────────────────────────────
// Spacing（4 の倍数）
// ─────────────────────────────────────────────

abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// 画面左右の余白
  static const double screenH = lg;

  /// カード内側の余白
  static const double cardPadding = xl;
}
