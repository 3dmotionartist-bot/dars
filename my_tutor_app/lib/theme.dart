import 'package:flutter/material.dart';

/// Dars brand palette. Own identity (teal + amber) — not a copy of Modarby's coral.
class AppColors {
  static const primary = Color(0xFF0E8F7E);
  static const primaryDark = Color(0xFF0A6E61);
  static const primarySoft = Color(0xFFE4F4F1);
  static const accent = Color(0xFFF5A524);
  static const accentSoft = Color(0xFFFFF4DF);
  static const ink = Color(0xFF12203A);
  static const text2 = Color(0xFF5B6475);
  static const text3 = Color(0xFF8D93A1);
  static const line = Color(0xFFE6E8EE);
  static const surface = Color(0xFFF5F7FA);
  static const success = Color(0xFF22B573);
  static const successSoft = Color(0xFFE5F7EE);
  static const danger = Color(0xFFE5484D);
  static const dangerSoft = Color(0xFFFDECEC);
  static const info = Color(0xFF2F6BFF);
  static const infoSoft = Color(0xFFE8EFFF);
  static const lavender = Color(0xFFEEEAFE);
  static const lavenderInk = Color(0xFF5B45D6);
}

ThemeData buildTheme() {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );

  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    dividerColor: AppColors.line,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.text3),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.primary, 1.6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.line,
        minimumSize: const Size(0, 52),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(0, 52),
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
      ),
    ),
  );
}
