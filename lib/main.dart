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
  StreamSubscription<Uri?>? _widgetSubscription;
  Uri? _lastProcessedUri;
  DateTime? _lastProcessedTime;

  @override
  void initState() {
    super.initState();
    print('DEBUG: _BirikimlyAppState.initState called');
    _appLinks = AppLinks();
    _initDeepLinks();
  }

  void _initDeepLinks() async {
    print('DEBUG: _initDeepLinks called');
    // Handle app_links initial link
    try {
      final initialUri = await _appLinks.getInitialLink();
      print('DEBUG: initialUri = $initialUri');
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      print('Failed to get initial deep link: $e');
    }

    // Handle app_links stream
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      print('DEBUG: uriLinkStream emitted $uri');
      _handleDeepLink(uri);
    });

    // Handle HomeWidget initially launched link
    try {
      final initialWidgetUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      print('DEBUG: initialWidgetUri = $initialWidgetUri');
      if (initialWidgetUri != null) {
        _handleDeepLink(initialWidgetUri);
      }
    } catch (e) {
      print('Failed to get initial widget link: $e');
    }

    // Handle HomeWidget click stream
    _widgetSubscription = HomeWidget.widgetClicked.listen((uri) {
      print('DEBUG: HomeWidget.widgetClicked emitted $uri');
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  void _handleDeepLink(Uri uri) {
    print('DEBUG: _handleDeepLink called with uri = $uri');
    if (uri.host == 'add_expense' || uri.host == 'add_income') {
      final now = DateTime.now();
      if (_lastProcessedUri == uri &&
          _lastProcessedTime != null &&
          now.difference(_lastProcessedTime!).inMilliseconds < 1500) {
        print('DEBUG: Duplicate deep link ignored (timestamp check: <1500ms)');
        return;
      }
      _lastProcessedUri = uri;
      _lastProcessedTime = now;
      
      final routeName = '/${uri.host}';
      
      // Delay slightly to ensure Navigator is fully initialized if cold boot
      Future.delayed(const Duration(milliseconds: 100), () {
        if (navigatorKey.currentState != null) {
          // Close any open dialogs/screens by popping until root
          navigatorKey.currentState!.popUntil((route) => route.isFirst);
          // Push the new wizard screen
          navigatorKey.currentState!.pushNamed(routeName);
        }
      });
    }
  }

  @override
  void dispose() {
    print('DEBUG: _BirikimlyAppState.dispose called');
    _linkSubscription?.cancel();
    _widgetSubscription?.cancel();
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
        onGenerateRoute: (settings) {
          // Catch any leftover native deep links from cached widgets
          // that try to push these paths to the navigator natively.
          if (settings.name == '/add_expense' || settings.name == '/add_income') {
            final isIncome = settings.name == '/add_income';
            return PageRouteBuilder(
              opaque: false,
              barrierDismissible: true,
              barrierColor: Colors.black54,
              pageBuilder: (context, _, __) => Dialog(
                alignment: Alignment.topCenter,
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: TransactionWizard(isIncome: isIncome),
              ),
              transitionDuration: const Duration(milliseconds: 200),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    ),
                    child: child,
                  ),
                );
              },
            );
          }
          return null; // Let Flutter handle other routes normally
        },
        home: const AuthGate(),
      ),
    );
  }
}
