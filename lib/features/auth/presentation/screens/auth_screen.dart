import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum AuthMode { login, register, forgotPassword }

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(); // Used for login
  final _otpController = TextEditingController(); // Used for OTP
  AuthMode _authMode = AuthMode.login;
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
    FocusScope.of(context).unfocus(); // Klavyeyi kapat
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    if (_authMode == AuthMode.login) {
      final password = _passwordController.text.trim();
      if (password.isEmpty) return;
      ref.read(authNotifierProvider.notifier).signInWithEmail(email, password);
    } else if (_authMode == AuthMode.register) {
      if (!_isOtpSent) {
        // Step 1: Send OTP
        ref.read(authNotifierProvider.notifier).sendOtp(email).then((_) {
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
    } else if (_authMode == AuthMode.forgotPassword) {
      if (!_isOtpSent) {
        ref.read(authNotifierProvider.notifier).sendPasswordResetOtp(email).then((_) {
          if (!ref.read(authNotifierProvider).hasError) {
            setState(() {
              _isOtpSent = true;
            });
          }
        });
      } else {
        final otp = _otpController.text.trim();
        if (otp.isEmpty) return;
        ref.read(authNotifierProvider.notifier).verifyPasswordResetOtp(email, otp);
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
          String message = 'Bir hata oluştu. Lütfen tekrar deneyin.';
          
          if (error is AuthException) {
            final loginError = error.message.toLowerCase();
            if (loginError.contains('invalid login credentials')) {
              message = 'Şifre hatalı.';
            } else if (loginError.contains('email not confirmed')) {
              message = 'Lütfen önce e-posta adresinizi doğrulayın.';
            } else if (loginError.contains('user not found')) {
              message = 'Kullanıcı bulunamadı. Lütfen kayıt olun.';
            } else if (loginError.contains('too many requests')) {
              message = 'Çok fazla istek gönderildi. Lütfen biraz bekleyin.';
            } else if (loginError.contains('over verification limit')) {
              message = 'Doğrulama sınırı aşıldı. Lütfen daha sonra tekrar deneyin.';
            } else if (loginError.contains('invalid format')) {
              message = 'E-posta formatı geçersiz.';
            } else {
              message = error.message; // Fallback to original if unknown
            }
          } else {
            // For other exceptions (like PostgrestException or custom exceptions)
            final errMsg = error.toString();
            if (errMsg.contains('check_email_exists')) {
              message = 'Lütfen önce SQL kodunu Supabase panelinde çalıştırın.';
            } else {
              message = error.toString().replaceAll('Exception: ', '').replaceAll('PostgrestException: ', '');
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(message),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        },
      );
    });

    return PopScope(
      canPop: _authMode == AuthMode.login && !_isOtpSent,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          if (_isOtpSent) {
            _isOtpSent = false;
          } else {
            _authMode = AuthMode.login;
          }
        });
      },
      child: Scaffold(
        appBar: (_authMode != AuthMode.login || _isOtpSent)
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  onPressed: () {
                    setState(() {
                      if (_isOtpSent) {
                        _isOtpSent = false;
                      } else {
                        _authMode = AuthMode.login;
                      }
                    });
                  },
                ),
              )
            : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Birikimly',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Gelir-Gider Dengeni Koru',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                if (_authMode == AuthMode.login || !_isOtpSent)
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
                if (_authMode == AuthMode.login) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    obscuringCharacter: '•',
                    textAlignVertical: TextAlignVertical.center,
                    style: GoogleFonts.robotoMono(
                      fontSize: 16,
                      height: 1.0,
                      letterSpacing: 2.0,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: const Icon(Icons.lock_outline),
                      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus(); // Klavyeyi kapat
                        setState(() {
                          _authMode = AuthMode.forgotPassword;
                          _isOtpSent = false;
                        });
                      },
                      child: Text(
                        'Şifremi Unuttum',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_authMode != AuthMode.login && _isOtpSent) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _otpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                    decoration: InputDecoration(
                      labelText: 'Doğrulama Kodu (6 Hane)',
                      prefixIcon: const Icon(Icons.key),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
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
                          _authMode == AuthMode.login
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
                    FocusScope.of(context).unfocus(); // Klavyeyi kapat
                    setState(() {
                      if (_authMode == AuthMode.login) {
                        _authMode = AuthMode.register;
                      } else {
                        _authMode = AuthMode.login;
                      }
                      _isOtpSent = false;
                    });
                  },
                  child: Text(
                    _authMode == AuthMode.login
                        ? 'Hesabın yok mu? Kayıt Ol'
                        : 'Zaten hesabın var mı? Giriş Yap',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    FocusScope.of(context).unfocus(); // Klavyeyi kapat
                    // Clear any existing Supabase session before entering guest mode
                    await ref.read(authNotifierProvider.notifier).signOut();
                    ref.read(guestModeProvider.notifier).setGuestMode(true);
                  },
                  child: Text(
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
      ), // Scaffold
    ); // PopScope
  }
}
