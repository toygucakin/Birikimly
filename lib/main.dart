import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:birikimly/core/services/supabase_service.dart';
import 'package:birikimly/core/theme/app_theme.dart';
import 'package:birikimly/features/auth/presentation/screens/auth_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';
import 'package:birikimly/core/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize date formatting
  await initializeDateFormatting('tr_TR', null);
  
  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await SupabaseService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const BirikimlyApp(),
    ),
  );
}

class BirikimlyApp extends ConsumerWidget {
  const BirikimlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MaterialApp(
        title: 'Birikimly',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const AuthGate(),
      ),
    );
  }
}
