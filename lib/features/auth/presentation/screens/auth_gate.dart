import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taptap/features/auth/presentation/providers/auth_provider.dart';
import 'package:taptap/features/auth/presentation/screens/auth_screen.dart';
import 'package:taptap/features/auth/presentation/screens/update_password_screen.dart';
import 'package:taptap/features/dashboard/presentation/screens/dashboard_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (state) {
        if (state.session != null) {
          final isAwaitingPassword = ref.watch(awaitingPasswordProvider);
          if (isAwaitingPassword) {
            return const UpdatePasswordScreen();
          }
          return const DashboardScreen();
        }
        return const AuthScreen();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Text('Authentication Error: $error'),
        ),
      ),
    );
  }
}
