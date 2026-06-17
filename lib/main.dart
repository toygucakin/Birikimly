import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:birikimly/core/services/supabase_service.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/core/theme/app_theme.dart';
import 'package:birikimly/features/auth/presentation/screens/auth_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';
import 'package:birikimly/core/providers/theme_provider.dart';
import 'package:birikimly/core/services/widget_service.dart';
import 'package:birikimly/core/providers/widget_sync_provider.dart';
import 'package:home_widget/home_widget.dart';
import 'package:birikimly/features/transactions/widgets/transaction_wizard.dart';

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
  
  // Initialize Home Widget Service
  await WidgetService.init();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const BirikimlyApp(),
    ),
  );
}

class BirikimlyApp extends ConsumerStatefulWidget {
  const BirikimlyApp({super.key});

  @override
  ConsumerState<BirikimlyApp> createState() => _BirikimlyAppState();
}

class _BirikimlyAppState extends ConsumerState<BirikimlyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    HomeWidget.widgetClicked.listen(_checkForWidgetLaunch);
    _checkForWidgetLaunch(null);
  }

  void _checkForWidgetLaunch(Uri? uri) async {
    if (uri == null) {
      uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    }
    
    if (uri != null) {
      if (uri.host == 'add_expense' || uri.host == 'add_income') {
        final isIncome = uri.host == 'add_income';
        // Wait a tiny bit for the UI to be ready if launched cold
        Future.delayed(const Duration(milliseconds: 500), () {
          if (navigatorKey.currentState != null) {
            showModalBottomSheet(
              context: navigatorKey.currentState!.context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => TransactionWizard(
                isIncome: isIncome,
              ),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep widget sync provider alive
    ref.watch(widgetSyncProvider);

    final preset = ref.watch(themeProvider);
    
    // Set the global dynamic palette
    AppColors.setPalette(preset.palette);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MaterialApp(
        title: 'Birikimly',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.buildTheme(preset.palette),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('tr', 'TR'),
        ],
        locale: const Locale('tr', 'TR'),
        navigatorKey: navigatorKey,
        home: const AuthGate(),
      ),
    );
  }
}
