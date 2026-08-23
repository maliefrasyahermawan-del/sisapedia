import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_mode.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/auth_error_mapper.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!ok && mounted) {
      final error = ref.read(authControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapAuthError(error ?? Exception()))),
      );
    }
  }

  void _enterAs(SessionMode mode) {
    ref.read(sessionModeProvider.notifier).state = mode;
    context.go('/role');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email', style: AppTextStyles.bodyBold),
                      Text(
                        'Nomor HP juga dapat digunakan dengan OTP',
                        style: AppTextStyles.captionMuted,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: '08xx-xxxx-xxxx',
                        ),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Masukkan email yang valid'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text('Kata Sandi', style: AppTextStyles.bodyBold),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Minimal 6 karakter',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Kata sandi minimal 6 karakter'
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Segera hadir.')),
                              ),
                          child: const Text('Lupa kata sandi?'),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _phoneOtp,
                          icon: const Icon(Icons.sms_outlined, size: 18),
                          label: const Text('Masuk dengan OTP nomor HP'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Masuk'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/register'),
                          child: const Text('Belum punya akun? Daftar'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'atau',
                              style: AppTextStyles.captionMuted,
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _enterAs(SessionMode.guest),
                          icon: const Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Masuk sebagai Tamu'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _enterAs(SessionMode.demo),
                          icon: const Icon(Icons.science_outlined, size: 18),
                          label: const Text('Masuk sebagai Akun Testing'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent700,
                            side: const BorderSide(color: AppColors.accent700),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _phoneOtp() async {
    final phone = TextEditingController();
    final token = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('OTP nomor HP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor HP'),
            ),
            TextField(
              controller: token,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kode OTP (setelah dikirim)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(authRepositoryProvider)
                    .sendPhoneOtp(phone.text.trim());
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Kode OTP dikirim.')),
                  );
                }
              } catch (_) {}
            },
            child: const Text('Kirim OTP'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Verifikasi'),
          ),
        ],
      ),
    );
    if (submit == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref
            .read(authRepositoryProvider)
            .verifyPhoneOtp(phone: phone.text.trim(), token: token.text.trim());
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('OTP belum dapat diverifikasi.')),
        );
      }
    }
    phone.dispose();
    token.dispose();
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF14B881), AppColors.primary, Color(0xFF06603F)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -40,
              right: -60,
              child: Opacity(
                opacity: 0.14,
                child: Container(
                  width: 220,
                  height: 150,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'SisaPedia',
                  style: AppTextStyles.brand.copyWith(fontSize: 22),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
