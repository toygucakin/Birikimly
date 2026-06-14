import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_palette.dart';

class AppTheme {
  static ThemeData buildTheme(ThemePalette palette) {
    final baseTheme = palette.isDark ? ThemeData.dark() : ThemeData.light();
    
    return ThemeData(
      brightness: palette.isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: palette.background,
      primaryColor: palette.primary,
      colorScheme: palette.isDark
          ? ColorScheme.dark(
              primary: palette.primary,
              secondary: palette.secondary,
              surface: palette.surface,
              error: palette.expense,
            )
          : ColorScheme.light(
              primary: palette.primary,
              secondary: palette.secondary,
              surface: palette.surface,
              error: palette.expense,
            ),
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          color: palette.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.outfit(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get darkTheme => buildTheme(MidnightPalette());
  static ThemeData get lightTheme => buildTheme(ClassicLightPalette());
}
