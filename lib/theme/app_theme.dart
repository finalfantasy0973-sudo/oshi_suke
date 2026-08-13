import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// アプリ全体のブランドカラーとグラデーション。
class AppColors {
  AppColors._();

  // ベース：くすみ系のローズ＋ラベンダー
  static const Color primary = Color(0xFFE91E8C); // 推し色っぽい鮮やかピンク
  static const Color primaryDark = Color(0xFFB81472);
  static const Color secondary = Color(0xFF8E63FF); // ラベンダー
  static const Color tertiary = Color(0xFFFFB347); // アクセント黄
  static const Color background = Color(0xFFFDF7FB); // ほんのりピンクの背景
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF4EEF6);
  static const Color outline = Color(0xFFE3D6E5);

  // ステータスカラー
  static const Color statusDeadline = Color(0xFFEF4D6F); // 締切間近
  static const Color statusReservation = Color(0xFF3B82F6); // 予約受付中
  static const Color statusActive = Color(0xFF22C55E); // 開催中
  static const Color statusUpcoming = Color(0xFF8E63FF); // 近日開始
  static const Color statusBefore = Color(0xFF94A3B8); // 予約受付前
  static const Color statusEnded = Color(0xFFB7B5BD); // 終了
}

class AppGradients {
  AppGradients._();

  /// ヘッダー等で使うピンク→紫の推し活グラデ
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7AB6), Color(0xFFB67CFF)],
  );

  static const LinearGradient deadline = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6F8E), Color(0xFFFF8AA1)],
  );

  static const LinearGradient active = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF38D196), Color(0xFF2BC0E4)],
  );

  static const LinearGradient reservation = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6DA9FF), Color(0xFF7C84FF)],
  );

  static const LinearGradient upcoming = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB67CFF), Color(0xFFE08CFF)],
  );

  /// 各カードのカテゴリ画像エリア用に、カテゴリごとに使い分ける淡いグラデ
  static const List<List<Color>> categoryPalette = [
    [Color(0xFFFFD2E1), Color(0xFFFFE9C7)],
    [Color(0xFFE7DFFF), Color(0xFFD7EBFF)],
    [Color(0xFFD8F5E5), Color(0xFFCDEBFF)],
    [Color(0xFFFEE6CB), Color(0xFFFFD2D2)],
    [Color(0xFFE2DBFF), Color(0xFFFCE0EF)],
    [Color(0xFFCEEFFA), Color(0xFFE6D6FF)],
  ];
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    tertiary: AppColors.tertiary,
    surface: AppColors.surface,
  );

  // ── Noto Sans JP を全画面に適用 ──────────────────────────────────────────
  // 端末標準フォントだとレンダラ依存で「ドット風」に見えることがあるため、
  // google_fonts 経由で明示的に Noto Sans JP を読み込ませて統一する。
  // GoogleFonts.notoSansJp() は同期で TextStyle を返し、フォント本体は
  // 初回のみ非同期ダウンロード→端末キャッシュされる。
  final notoFamily = GoogleFonts.notoSansJp().fontFamily;

  TextStyle noto({
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) =>
      GoogleFonts.notoSansJp(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      );

  final notoTextTheme = TextTheme(
    titleLarge: noto(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.25,
        letterSpacing: -0.2),
    titleMedium: noto(fontSize: 16, fontWeight: FontWeight.w800, height: 1.3),
    titleSmall: noto(fontSize: 14, fontWeight: FontWeight.w700, height: 1.3),
    bodyLarge: noto(fontSize: 14, height: 1.45),
    bodyMedium: noto(fontSize: 13, height: 1.45),
    bodySmall: noto(fontSize: 12, height: 1.4),
    labelLarge: noto(fontSize: 13, fontWeight: FontWeight.w700),
    labelMedium: noto(fontSize: 12, fontWeight: FontWeight.w700),
    labelSmall: noto(fontSize: 11, fontWeight: FontWeight.w700),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    // インライン TextStyle (fontFamily 未指定) もこのフォントで描画される
    fontFamily: notoFamily,
    fontFamilyFallback: const ['Roboto', 'sans-serif'],
    textTheme: notoTextTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: const Color(0xFF2A1F33),
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: noto(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF2A1F33),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.outline, width: 0.6),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceMuted,
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      side: BorderSide.none,
      labelStyle: noto(fontSize: 12, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outline,
      thickness: 0.6,
      space: 0.6,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      hintStyle: noto(color: const Color(0xFF9C8FA3), fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: noto(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.outline),
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: noto(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      indicatorColor: AppColors.primary.withValues(alpha: 0.14),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return noto(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.primary : const Color(0xFF6B5C72),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.primary : const Color(0xFF6B5C72),
          size: 24,
        );
      }),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  );
}
