import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/preview/preview_mode.dart';
import '../../core/session/session_mode.dart';
import '../../core/session/testing_accounts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/firebase_error_mapper.dart';
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
    final ok = await ref.read(authControllerProvider.notifier).signIn(
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

  SessionMode? _enteringTestingMode;

  Future<void> _enterAs(SessionMode mode) async {
    final isTestingAccount =
        mode == SessionMode.demo || mode == SessionMode.pengolahDemo;
    // A real PREVIEW_MODE build never calls Firebase.initializeApp, so the
    // testing accounts stay fully local/offline there — signing in for real
    // only happens on a normal build, where the two testing buttons now
    // share one real Firebase identity across devices (see
    // testing_accounts.dart).
    if (isTestingAccount && !kPreviewMode) {
      setState(() => _enteringTestingMode = mode);
      try {
        await signInTestingAccount(
          mode == SessionMode.demo
              ? kTestingSumberAccount
              : kTestingPengolahAccount,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _enteringTestingMode = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal masuk akun testing: ${mapAuthError(e)}')),
          );
        }
        return;
      }
    }
    ref.read(sessionModeProvider.notifier).state = mode;
    if (mounted) {
      setState(() => _enteringTestingMode = null);
      context.go(mode == SessionMode.pengolahDemo ? '/pengolah' : '/beranda');
    }
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
                      Text('Nomor HP atau Email', style: AppTextStyles.bodyBold),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration:
                            const InputDecoration(hintText: '08xx-xxxx-xxxx'),
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
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('atau',
                                style: AppTextStyles.captionMuted),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _enterAs(SessionMode.guest),
                          icon: const Icon(Icons.person_outline_rounded,
                              size: 18),
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
                          onPressed: _enteringTestingMode != null
                              ? null
                              : () => _enterAs(SessionMode.demo),
                          icon: _enteringTestingMode == SessionMode.demo
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.science_outlined, size: 18),
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
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _enteringTestingMode != null
                              ? null
                              : () => _enterAs(SessionMode.pengolahDemo),
                          icon: _enteringTestingMode == SessionMode.pengolahDemo
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.recycling_outlined, size: 18),
                          label: const Text('Masuk sebagai Akun Pengolah (Testing)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1D4ED8),
                            side: const BorderSide(color: Color(0xFF1D4ED8)),
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
                      color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
            Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.asset('assets/icon/app_icon.png'),
                ),
                const SizedBox(height: 10),
                Text('SisaPedia', style: AppTextStyles.brand.copyWith(fontSize: 22)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
