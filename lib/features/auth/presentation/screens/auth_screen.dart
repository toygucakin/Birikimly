import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(); // Used for login
  final _otpController = TextEditingController(); // Used for OTP
  bool _isLogin = true;
  bool _isOtpSent = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    if (_isLogin) {
      final password = _passwordController.text.trim();
      if (password.isEmpty) return;
      ref.read(authNotifierProvider.notifier).signInWithEmail(email, password);
    } else {
      if (!_isOtpSent) {
        // Step 1: Send OTP
        ref.read(authNotifierProvider.notifier).sendOtp(email).then((_) {
          // If no error, set OTP sent to true
          if (!ref.read(authNotifierProvider).hasError) {
            setState(() {
              _isOtpSent = true;
            });
          }
        });
      } else {
        // Step 2: Verify OTP
        final otp = _otpController.text.trim();
        if (otp.isEmpty) return;
        ref.read(authNotifierProvider.notifier).verifyOtp(email, otp);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // React to errors
    ref.listen<AsyncValue<void>>(authNotifierProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          final message = error is AuthException ? error.message : error.toString();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(message),
            backgroundColor: AppColors.expense,
          ));
        },
      );
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'TapTap',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Finansal Özgürlüğe Hoş Geldin',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                if (_isLogin || !_isOtpSent)
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                if (_isLogin) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
                if (!_isLogin && _isOtpSent) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Doğrulama Kodu (6 Hane)',
                      prefixIcon: const Icon(Icons.key),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isLogin 
                              ? 'Giriş Yap' 
                              : (_isOtpSent ? 'Doğrula' : 'Kod Gönder'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _isOtpSent = false;
                    });
                  },
                  child: Text(
                    _isLogin
                        ? 'Hesabın yok mu? Kayıt Ol'
                        : 'Zaten hesabın var mı? Giriş Yap',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    // Clear any existing Supabase session before entering guest mode
                    await ref.read(authNotifierProvider.notifier).signOut();
                    ref.read(guestModeProvider.notifier).setGuestMode(true);
                  },
                  child: const Text(
                    'Misafir olarak giriş yap',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
