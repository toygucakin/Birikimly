import 'package:flutter/material.dart';
import 'theme_palette.dart';

class AppColors {
  static ThemePalette _currentPalette = MidnightPalette();

  static void setPalette(ThemePalette palette) {
    _currentPalette = palette;
  }

  static ThemePalette get current => _currentPalette;

  static Color get background => _currentPalette.background;
  static Color get surface => _currentPalette.surface;
  static Color get primary => _currentPalette.primary;
  static Color get secondary => _currentPalette.secondary;
  static Color get accent => _currentPalette.accent;
  
  static Color get income => _currentPalette.income;
  static Color get expense => _currentPalette.expense;
  
  static Color get textPrimary => _currentPalette.textPrimary;
  static Color get textSecondary => _currentPalette.textSecondary;

  static List<Color> get cardGradient => _currentPalette.cardGradient;
}
