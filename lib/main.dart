import 'dart:io';
import 'dart:async';
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
import 'package:app_links/app_links.dart';
import 'package:birikimly/features/transactions/widgets/transaction_wizard.dart';
import 'package:birikimly/core/providers/deep_link_provider.dart';

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

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
  }

  void _initDeepLinks() async {
    // Handle initial link if app was closed
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      print('Failed to get initial deep link: $e');
    }

    // Handle deep links while app is open
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.host == 'add_expense' || uri.host == 'add_income') {
      ref.read(deepLinkProvider.notifier).setUri(uri);
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
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
