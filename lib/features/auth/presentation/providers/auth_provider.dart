import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:birikimly/core/services/supabase_service.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user ?? SupabaseService.client.auth.currentUser;
});

class AwaitingPasswordNotifier extends Notifier<bool> {
  @override
  bool build() {
    final sub = SupabaseService.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        state = true;
      }
    });
    ref.onDispose(() => sub.cancel());
    return false;
  }

  void set(bool value) => state = value;
}

final awaitingPasswordProvider = NotifierProvider<AwaitingPasswordNotifier, bool>(AwaitingPasswordNotifier.new);

class AuthNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 10));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      print('SignIn Error: $e');
      print(st);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> sendOtp(String email) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.client.auth.signInWithOtp(email: email).timeout(const Duration(seconds: 10));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      print('SendOtp Error: $e');
      print(st);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> verifyOtp(String email, String token) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
      ref.read(awaitingPasswordProvider.notifier).set(true);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      print('VerifyOtp Error: $e');
      print(st);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> sendPasswordResetOtp(String email) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(email).timeout(const Duration(seconds: 10));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      print('SendPasswordResetOtp Error: $e');
      print(st);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> verifyPasswordResetOtp(String email, String token) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      ref.read(awaitingPasswordProvider.notifier).set(true);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      print('VerifyPasswordResetOtp Error: $e');
      print(st);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateUserPassword(String password) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: password),
      );
      ref.read(awaitingPasswordProvider.notifier).set(false);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.client.auth.signOut().timeout(const Duration(seconds: 10));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateDisplayName(String name) async {
    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(data: {'display_name': name}),
      );
    } catch (e) {
      print('Failed to update display name: $e');
    }
  }

  Future<void> updateMonthlyLimit(double? limit) async {
    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(data: {'monthly_limit': limit}),
      );
    } catch (e) {
      print('Failed to update monthly limit: $e');
    }
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AsyncValue<void>>(AuthNotifier.new);
