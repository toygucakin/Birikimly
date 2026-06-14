import 'package:flutter/material.dart';
import 'package:birikimly/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:birikimly/features/profile/presentation/screens/profile_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/features/main/presentation/providers/main_screen_provider.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/core/services/recurring_transaction_service.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start sync service when main screen is built (user is logged in)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = ref.read(currentUserProvider);
      final isGuest = ref.read(guestModeProvider);
      if (user != null || isGuest) {
        final userId = isGuest ? 'guest' : user!.id;
        final processed = await ref.read(recurringTransactionServiceProvider).processRecurringTransactions(userId);
        if (processed > 0 && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$processed adet yeni düzenli işlem hesabınıza eklendi.'),
              backgroundColor: const Color(0xFF22C55E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
      ref.read(syncServiceProvider).start();
    });

    final pageController = ref.watch(mainPageControllerProvider);

    return Scaffold(
      body: ListenableBuilder(
        listenable: pageController,
        builder: (context, child) {
          final isProfile = pageController.hasClients && pageController.page?.round() == 1;
          return PopScope(
            canPop: !isProfile,
            onPopInvoked: (didPop) {
              if (didPop) return;
              if (isProfile) {
                pageController.animateToPage(
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
          controller: pageController,
          children: const [
            DashboardScreen(),
            ProfileScreen(),
          ],
        ),
      ),
    );
  }
}
