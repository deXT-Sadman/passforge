import 'package:flutter/material.dart';

/// PassForge brand palette.
abstract final class AppColors {
  static const primary = Color(0xFF00ADB5); // Deep teal / cyan
  static const primaryBright = Color(0xFF00E5FF);
  static const primaryOnLight = Color(0xFF00838F); // darker teal: readable on white
  static const success = Color(0xFF00E676); // Emerald accent
  static const successOnLight = Color(0xFF00A152);
  static const error = Color(0xFFFF5370);

  // Dark surfaces
  static const background = Color(0xFF1E1E2E); // Charcoal dark
  static const surface = Color(0xFF252836); // Dark slate (cards)
  static const surfaceHigh = Color(0xFF2E3144);

  // Light surfaces
  static const backgroundLight = Color(0xFFF3F5F9);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceHighLight = Color(0xFFE8ECF3);
}

abstract final class AppTheme {
  static ThemeData get dark => _build(
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.black,
          secondary: AppColors.success,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        background: AppColors.background,
        surfaceHigh: AppColors.surfaceHigh,
      );

  static ThemeData get light => _build(
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primaryOnLight,
          onPrimary: Colors.white,
          secondary: AppColors.successOnLight,
          surface: AppColors.surfaceLight,
          error: const Color(0xFFD32F4F),
        ),
        background: AppColors.backgroundLight,
        surfaceHigh: AppColors.surfaceHighLight,
      );

  static ThemeData _build(
    ColorScheme scheme, {
    required Color background,
    required Color surfaceHigh,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        focusedBorder: border(scheme.primary, 1.5),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 1.5),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: scheme.surface),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
