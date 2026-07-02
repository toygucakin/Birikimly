import 'package:flutter/material.dart';
import 'package:birikimly/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:birikimly/features/profile/presentation/screens/profile_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/core/services/recurring_transaction_service.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/features/transactions/widgets/processed_transactions_dialog.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with WidgetsBindingObserver {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    print('DEBUG: _MainScreenState.initState called');
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
    
    // Start sync service when main screen is built (user is logged in)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = ref.read(currentUserProvider);
      final isGuest = ref.read(guestModeProvider);
      if (user != null || isGuest) {
        final userId = isGuest ? 'guest' : user!.id;
        
        // Sync first to get the latest nextExecutionDate from the cloud before processing recurring transactions
        if (!isGuest) {
          print('DEBUG: Syncing before processing recurring transactions...');
          await ref.read(syncServiceProvider).syncAll();
        }

        final processedTxs = await ref.read(recurringTransactionServiceProvider).processRecurringTransactions(userId);
        if (processedTxs.isNotEmpty && mounted) {
          final allRecurring = await ref.read(databaseProvider).getAllRecurringTransactions(userId);
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => ProcessedTransactionsDialog(
              transactions: processedTxs,
              allRecurring: allRecurring,
              userId: userId,
            ),
          );
        }
      }
      ref.read(syncServiceProvider).start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final isGuest = ref.read(guestModeProvider);
      if (!isGuest) {
        print('DEBUG: App resumed, triggering sync...');
        ref.read(syncServiceProvider).syncAll();
      }
    }
  }

  @override
  void dispose() {
    print('DEBUG: _MainScreenState.dispose called');
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: ListenableBuilder(
        listenable: _pageController,
        builder: (context, child) {
          bool isProfile = false;
          if (_pageController.hasClients) {
            try {
              if (_pageController.position.haveDimensions) {
                isProfile = _pageController.page?.round() == 1;
              }
            } catch (_) {}
          }
          return PopScope(
            canPop: !isProfile,
            onPopInvoked: (didPop) {
              if (didPop) return;
              if (isProfile) {
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: child!,
          );
        },
        child: PageView(
          controller: _pageController,
          children: [
            DashboardScreen(pageController: _pageController),
            ProfileScreen(pageController: _pageController),
          ],
        ),
      ),
    );
  }
}
