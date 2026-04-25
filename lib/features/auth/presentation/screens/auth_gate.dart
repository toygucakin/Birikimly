import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/features/auth/presentation/screens/auth_screen.dart';
import 'package:birikimly/features/auth/presentation/screens/update_password_screen.dart';
import 'package:birikimly/features/main/presentation/screens/main_screen.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(guestModeProvider);
    if (isGuest) {
      return const MainScreen();
    }

    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (state) {
        if (state.session != null) {
          final isAwaitingPassword = ref.watch(awaitingPasswordProvider);
          if (isAwaitingPassword) {
            return const UpdatePasswordScreen();
          }
          return const MainScreen();
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
