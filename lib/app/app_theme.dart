import 'package:flutter/material.dart';

/// アプリアイコン（水彩・辞書）の落ち着いたブルー／クリーム／ミント系に寄せたライトテーマ。
/// Material の既定インディゴ／紫寄りのシードは使わない。
ThemeData buildAppTheme() {
  const denim = Color(0xFF4A6574);
  const cream = Color(0xFFF7F5F0);
  const paper = Color(0xFFFDFCF8);
  const mint = Color(0xFF6E9B8E);
  const sand = Color(0xFFD8CCA8);

  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF5B7C8D),
    brightness: Brightness.light,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );

  final scheme = base.copyWith(
    primary: denim,
    onPrimary: paper,
    primaryContainer: const Color(0xFFC5D6DE),
    onPrimaryContainer: const Color(0xFF1E2A32),
    secondary: mint,
    onSecondary: paper,
    secondaryContainer: const Color(0xFFC5DDD4),
    onSecondaryContainer: const Color(0xFF1A2824),
    tertiary: sand,
    onTertiary: const Color(0xFF2C281E),
    tertiaryContainer: const Color(0xFFEDE6D4),
    onTertiaryContainer: const Color(0xFF3D3828),
    surface: cream,
    onSurface: const Color(0xFF2A3339),
    onSurfaceVariant: const Color(0xFF5C656B),
    surfaceContainerLowest: paper,
    surfaceContainerLow: const Color(0xFFF3F0EA),
    surfaceContainer: const Color(0xFFEDEAE3),
    surfaceContainerHigh: const Color(0xFFE6E2DA),
    surfaceContainerHighest: const Color(0xFFDEDAD2),
    outline: const Color(0xFF9CA8AE),
    outlineVariant: const Color(0xFFD0D5D8),
    surfaceTint: denim,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: cream,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: paper,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: denim,
        foregroundColor: paper,
      ),
    ),
  );
}
