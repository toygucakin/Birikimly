import 'package:flutter/material.dart';
import 'package:birikimly/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:birikimly/features/profile/presentation/screens/profile_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/features/main/presentation/providers/main_screen_provider.dart';
import 'package:birikimly/core/database/database.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start sync service when main screen is built (user is logged in)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider).start();
    });

    final pageController = ref.watch(mainPageControllerProvider);

    return Scaffold(
      body: PageView(
        controller: pageController,
        children: const [
          DashboardScreen(),
          ProfileScreen(),
        ],
      ),
    );
  }
}
