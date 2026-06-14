import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';
import 'package:birikimly/core/theme/theme_palette.dart';

enum AppThemePreset {
  midnight,
  emerald,
  cyberpunk,
  amethyst,
  sunset,
  sapphireBlue,
  creamBlue,
  classicLight,
  oceanBlue,
  sakuraPink,
}

extension AppThemePresetExtension on AppThemePreset {
  ThemePalette get palette {
    switch (this) {
      case AppThemePreset.midnight:
        return MidnightPalette();
      case AppThemePreset.emerald:
        return ForestEmeraldPalette();
      case AppThemePreset.cyberpunk:
        return CyberpunkPalette();
      case AppThemePreset.amethyst:
        return AmethystPalette();
      case AppThemePreset.sunset:
        return SunsetRosePalette();
      case AppThemePreset.sapphireBlue:
        return SapphireBluePalette();
      case AppThemePreset.creamBlue:
        return CreamBluePalette();
      case AppThemePreset.classicLight:
        return ClassicLightPalette();
      case AppThemePreset.oceanBlue:
        return OceanBluePalette();
      case AppThemePreset.sakuraPink:
        return SakuraPinkPalette();
    }
  }

  String get displayName {
    switch (this) {
      case AppThemePreset.midnight:
        return 'Gece Yarısı';
      case AppThemePreset.emerald:
        return 'Zümrüt Ormanı';
      case AppThemePreset.cyberpunk:
        return 'Kehribar Sarısı';
      case AppThemePreset.amethyst:
        return 'Ametist Lavanta';
      case AppThemePreset.sunset:
        return 'Kızıl Günbatımı';
      case AppThemePreset.sapphireBlue:
        return 'Safir Mavi';
      case AppThemePreset.creamBlue:
        return 'Krem Mavi';
      case AppThemePreset.classicLight:
        return 'Klasik Aydınlık';
      case AppThemePreset.oceanBlue:
        return 'Okyanus Mavisi';
      case AppThemePreset.sakuraPink:
        return 'Sakura Pembe';
    }
  }
}

class ThemePresetNotifier extends Notifier<AppThemePreset> {
  static const _key = 'theme_preset_name';

  @override
  AppThemePreset build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getString(_key);
    if (saved != null) {
      try {
        return AppThemePreset.values.byName(saved);
      } catch (_) {
        // Fallback
      }
    }
    
    // Check legacy theme
    final legacyTheme = prefs.getString('theme_mode');
    if (legacyTheme == 'light') {
      return AppThemePreset.classicLight;
    }
    
    return AppThemePreset.midnight;
  }

  void setPreset(AppThemePreset preset) {
    state = preset;
    ref.read(sharedPreferencesProvider).setString(_key, preset.name);
  }
}

final themeProvider = NotifierProvider<ThemePresetNotifier, AppThemePreset>(ThemePresetNotifier.new);
