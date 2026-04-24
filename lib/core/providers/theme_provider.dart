import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedTheme = prefs.getString(_key);
    if (savedTheme == 'light') {
      return ThemeMode.light;
    }
    return ThemeMode.dark;
  }

  void toggleTheme() {
    final prefs = ref.read(sharedPreferencesProvider);
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
      prefs.setString(_key, 'light');
    } else {
      state = ThemeMode.dark;
      prefs.setString(_key, 'dark');
    }
  }

  bool get isDarkMode => state == ThemeMode.dark;
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);
