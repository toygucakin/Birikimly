import 'package:flutter/material.dart';
import 'package:birikimly/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:birikimly/features/profile/presentation/screens/profile_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/core/services/recurring_transaction_service.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/core/utils/currency_utils.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    print('DEBUG: _MainScreenState.initState called');
    _pageController = PageController();
    
    // Start sync service when main screen is built (user is logged in)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = ref.read(currentUserProvider);
      final isGuest = ref.read(guestModeProvider);
      if (user != null || isGuest) {
        final userId = isGuest ? 'guest' : user!.id;
        final processedTxs = await ref.read(recurringTransactionServiceProvider).processRecurringTransactions(userId);
        if (processedTxs.isNotEmpty && mounted) {
          if (processedTxs.length == 1) {
            final tx = processedTxs.first;
            final db = ref.read(databaseProvider);
            final categories = await db.getAllCategories(userId);
            final rawId = tx.categoryId?.trim() ?? '';
            final category = categories.firstWhere(
              (c) => c.uuid == rawId,
              orElse: () => categories.firstWhere(
                (c) => c.uuid.replaceAll('def_', '').replaceAll('temp_', '').toLowerCase() == rawId.replaceAll('def_', '').replaceAll('temp_', '').toLowerCase(),
                orElse: () => categories.first,
              ),
            );

            final categoryName = category.name;
            final typeStr = tx.isIncome ? 'geliriniz' : 'gideriniz';
            final descStr = tx.description.isNotEmpty ? "'${tx.description}' açıklamalı " : '';
            final amountStr = CurrencyUtils.format(tx.amount);

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Bugün $categoryName kategorisinden $descStr$amountStr $typeStr hesabınıza eklendi.'),
                backgroundColor: const Color(0xFF22C55E),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 6),
              ),
            );
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${processedTxs.length} adet yeni düzenli işlem hesabınıza eklendi.'),
                backgroundColor: const Color(0xFF22C55E),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
      ref.read(syncServiceProvider).start();
    });
  }

  @override
  void dispose() {
    print('DEBUG: _MainScreenState.dispose called');
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
