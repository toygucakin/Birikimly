import 'package:flutter/material.dart';

abstract class ThemePalette {
  bool get isDark;
  Color get background;
  Color get surface;
  Color get primary;
  Color get secondary;
  Color get accent;
  Color get income;
  Color get expense;
  Color get textPrimary;
  Color get textSecondary;
  List<Color> get cardGradient;
}

// 1. Midnight Sky (Varsayılan Koyu Tema)
class MidnightPalette implements ThemePalette {
  @override
  bool get isDark => true;
  @override
  Color get background => const Color(0xFF0F172A);
  @override
  Color get surface => const Color(0xFF1E293B);
  @override
  Color get primary => const Color(0xFF6366F1);
  @override
  Color get secondary => const Color(0xFFEC4899);
  @override
  Color get accent => const Color(0xFF10B981);
  @override
  Color get income => const Color(0xFF10B981);
  @override
  Color get expense => const Color(0xFFEF4444);
  @override
  Color get textPrimary => Colors.white;
  @override
  Color get textSecondary => const Color(0xFF94A3B8);
  @override
  List<Color> get cardGradient => [primary, secondary];
}

// 2. Emerald Forest (Yeşil Tema)
class ForestEmeraldPalette implements ThemePalette {
  @override
  bool get isDark => true;
  @override
  Color get background => const Color(0xFF0A1210);
  @override
  Color get surface => const Color(0xFF12221E);
  @override
  Color get primary => const Color(0xFF10B981);
  @override
  Color get secondary => const Color(0xFF06B6D4);
  @override
  Color get accent => const Color(0xFFF59E0B);
  @override
  Color get income => const Color(0xFF10B981);
  @override
  Color get expense => const Color(0xFFEF4444);
  @override
  Color get textPrimary => Colors.white;
  @override
  Color get textSecondary => const Color(0xFF86A39B);
  @override
  List<Color> get cardGradient => [primary, secondary];
}

// 3. Cyber Amber (Amber & Turuncu Tema)
class CyberpunkPalette implements ThemePalette {
  @override
  bool get isDark => true;
  @override
  Color get background => const Color(0xFF0D0D0D);
  @override
  Color get surface => const Color(0xFF1C1A17);
  @override
  Color get primary => const Color(0xFFF59E0B);
  @override
  Color get secondary => const Color(0xFFF97316);
  @override
  Color get accent => const Color(0xFF10B981);
  @override
  Color get income => const Color(0xFF10B981);
  @override
  Color get expense => const Color(0xFFEF4444);
  @override
  Color get textPrimary => Colors.white;
  @override
  Color get textSecondary => const Color(0xFFB5A99E);
  @override
  List<Color> get cardGradient => [primary, secondary];
}

// 4. Royal Amethyst (Mor & Macenta Tema)
class AmethystPalette implements ThemePalette {
  @override
  bool get isDark => true;
  @override
  Color get background => const Color(0xFF0B0714);
  @override
  Color get surface => const Color(0xFF171123);
  @override
  Color get primary => const Color(0xFF8B5CF6);
  @override
  Color get secondary => const Color(0xFFD946EF);
  @override
  Color get accent => const Color(0xFF10B981);
  @override
  Color get income => const Color(0xFF10B981);
  @override
  Color get expense => const Color(0xFFEF4444);
  @override
  Color get textPrimary => Colors.white;
  @override
  Color get textSecondary => const Color(0xFF9E92B5);
  @override
  List<Color> get cardGradient => [primary, secondary];
}

// 5. Crimson Sunset (Gül Kırmızısı & Altın Tema)
class SunsetRosePalette implements ThemePalette {
  @override
  bool get isDark => true;
  @override
  Color get background => const Color(0xFF14080E);
  @override
  Color get surface => const Color(0xFF221018);
  @override
  Color get primary => const Color(0xFFF43F5E);
  @override
  Color get secondary => const Color(0xFFF59E0B);
  @override
  Color get accent => const Color(0xFF10B981);
  @override
  Color get income => const Color(0xFF10B981);
  @override
  Color get expense => const Color(0xFFEF4444);
  @override
  Color get textPrimary => Colors.white;
  @override
  Color get textSecondary => const Color(0xFFBCA6B2);
  @override
  List<Color> get cardGradient => [primary, secondary];
}

// 6. Classic Light (Aydınlık Tema)
class ClassicLightPalette implements ThemePalette {
  @override
  bool get isDark => false;
  @override
  Color get background => const Color(0xFFF5F7FA);
  @override
  Color get surface => Colors.white;
  @override
  Color get primary => const Color(0xFF6366F1);
  @override
  Color get secondary => const Color(0xFFEC4899);
  @override
  Color get accent => const Color(0xFF10B981);
  @override
  Color get income => const Color(0xFF10B981);
  @override
  Color get expense => const Color(0xFFEF4444);
  @override
  Color get textPrimary => const Color(0xFF1A1A1A);
  @override
  Color get textSecondary => const Color(0xFF64748B);
  @override
  List<Color> get cardGradient => [primary, secondary];
}

// 7. Cream Blue (Krem Mavi - Nike Air Max 1 ilhamlı)
class CreamBluePalette implements ThemePalette {
  @override
  bool get isDark => false;
  @override
  Color get background => const Color(0xFFFAF7F2); // Warm cream/off-white background
  @override
  Color get surface => Colors.white;
  @override
  Color get primary => const Color(0xFF1E7B88); // Nike Air Max mudguard teal
  @override
  Color get secondary => const Color(0xFF4FA0B0); // Swoosh/light teal accents
  @override
  Color get accent => const Color(0xFFE5D5C5); // Beige/cream suede overlays
  @override
  Color get income => const Color(0xFF10B981);
  @override
  Color get expense => const Color(0xFFEF4444);
  @override
  Color get textPrimary => const Color(0xFF20292B); // Dark slate/charcoal
  @override
  Color get textSecondary => const Color(0xFF7A8B8E); // Muted teal-grey
  @override
  List<Color> get cardGradient => [primary, secondary];
}

// 8. Sapphire Blue (Safir Mavi - Koyu Mavi Tema)
class SapphireBluePalette implements ThemePalette {
  @override
  bool get isDark => true;
  @override
  Color get background => const Color(0xFF070B19); // Deep sapphire dark background
  @override
  Color get surface => const Color(0xFF0F172A); // Deep slate-blue card surface
  @override
  Color get primary => const Color(0xFF3B82F6); // Electric/sapphire blue
  @override
  Color get secondary => const Color(0xFF00D2FF); // Light cyan/neon blue
  @override
  Color get accent => const Color(0xFFF59E0B);
  @override
  Color get income => const Color(0xFF10B981);
  @override
  Color get expense => const Color(0xFFEF4444);
  @override
  Color get textPrimary => Colors.white;
  @override
  Color get textSecondary => const Color(0xFF8BA2C0); // Soft grey-blue
  @override
  List<Color> get cardGradient => [primary, secondary];
}

// 9. Ocean Blue (Okyanus Mavisi - Açık Mavi Tema)
class OceanBluePalette implements ThemePalette {
  @override
  bool get isDark => false;
  @override
  Color get background => const Color(0xFFF5F9FC); // Fresh ocean breeze white/light blue
  @override
  Color get surface => Colors.white;
  @override
  Color get primary => const Color(0xFF0284C7); // Rich sky/ocean blue
  @override
  Color get secondary => const Color(0xFF0EA5E9); // Light blue accents
  @override
  Color get accent => const Color(0xFF0D9488); // Teal accent
  @override
  Color get income => const Color(0xFF10B981);
  @override
  Color get expense => const Color(0xFFEF4444);
  @override
  Color get textPrimary => const Color(0xFF0F172A); // Deep slate/black
  @override
  Color get textSecondary => const Color(0xFF64748B); // Slate grey
  @override
  List<Color> get cardGradient => [primary, secondary];
}

// 10. Sakura Pink (Sakura Pembe - Açık Pembe Tema)
class SakuraPinkPalette implements ThemePalette {
  @override
  bool get isDark => false;
  @override
  Color get background => const Color(0xFFFFF7F8); // Soft rose blossom white
  @override
  Color get surface => Colors.white;
  @override
  Color get primary => const Color(0xFFEC4899); // Sakura pink primary
  @override
  Color get secondary => const Color(0xFFF472B6); // Soft blush pink
  @override
  Color get accent => const Color(0xFF8B5CF6); // Lavender violet accent
  @override
  Color get income => const Color(0xFF10B981);
  @override
  Color get expense => const Color(0xFFEF4444);
  @override
  Color get textPrimary => const Color(0xFF1F2937); // Charcoal grey
  @override
  Color get textSecondary => const Color(0xFF6B7280); // Medium grey
  @override
  List<Color> get cardGradient => [primary, secondary];
}

// 11. Crimson Noir (Kadife Gül - Siyah/Kırmızı/Beyaz Koyu Tema)
class CrimsonNoirPalette implements ThemePalette {
  @override
  bool get isDark => true;
  @override
  Color get background => const Color(0xFF0A0A0A); // Jet black background
  @override
  Color get surface => const Color(0xFF161616); // Charcoal black surface
  @override
  Color get primary => const Color(0xFFE11D48); // Vibrant crimson red
  @override
  Color get secondary => Colors.white; // Pure white accents
  @override
  Color get accent => const Color(0xFFEF4444); // Accent red
  @override
  Color get income => const Color(0xFF10B981);
  @override
  Color get expense => const Color(0xFFEF4444);
  @override
  Color get textPrimary => Colors.white; // White text
  @override
  Color get textSecondary => const Color(0xFF9CA3AF); // Light grey text
  @override
  List<Color> get cardGradient => [primary, const Color(0xFF991B1B)]; // Crimson to dark red gradient
}

// 12. Scarlet Light (Mermer Alevi - Beyaz/Siyah/Kırmızı Açık Tema)
class ScarletLightPalette implements ThemePalette {
  @override
  bool get isDark => false;
  @override
  Color get background => const Color(0xFFFCFCFC); // Clean off-white background
  @override
  Color get surface => Colors.white;
  @override
  Color get primary => const Color(0xFFDC2626); // Scarlet red primary
  @override
  Color get secondary => const Color(0xFF0F172A); // Ink/slate black accents
  @override
  Color get accent => const Color(0xFF4B5563); // Muted slate grey
  @override
  Color get income => const Color(0xFF10B981);
  @override
  Color get expense => const Color(0xFFEF4444);
  @override
  Color get textPrimary => const Color(0xFF0F172A); // Ink black text
  @override
  Color get textSecondary => const Color(0xFF4B5563); // Slate grey text
  @override
  List<Color> get cardGradient => [primary, const Color(0xFF0F172A)]; // Scarlet to ink black gradient
}

