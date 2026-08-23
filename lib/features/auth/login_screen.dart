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
                          onPressed: _forgotPassword,
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
    await showDialog<bool>(
      context: context,
      builder: (_) => const _PhoneOtpDialog(),
    );
  }

  Future<void> _forgotPassword() async {
    final requested = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ResetPasswordDialog(initialEmail: _emailController.text.trim()),
    );
    if (requested == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Jika akun dengan email tersebut ada, tautan reset kata sandi akan dikirim.',
          ),
        ),
      );
    }
  }
}

String? _normalizeIndonesianPhone(String raw) {
  final compact = raw.replaceAll(RegExp(r'[\s().-]'), '');
  String normalized;
  if (compact.startsWith('+62')) {
    normalized = compact;
  } else if (compact.startsWith('62')) {
    normalized = '+$compact';
  } else if (compact.startsWith('08')) {
    normalized = '+62${compact.substring(1)}';
  } else {
    return null;
  }
  return RegExp(r'^\+628\d{8,11}$').hasMatch(normalized) ? normalized : null;
}

class _PhoneOtpDialog extends ConsumerStatefulWidget {
  const _PhoneOtpDialog();

  @override
  ConsumerState<_PhoneOtpDialog> createState() => _PhoneOtpDialogState();
}

class _PhoneOtpDialogState extends ConsumerState<_PhoneOtpDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _tokenController = TextEditingController();
  String? _normalizedPhone;
  String? _error;
  bool _sent = false;
  bool _sending = false;
  bool _verifying = false;

  bool get _showPreviewCode =>
      ref.read(sessionModeProvider) == SessionMode.demo;

  @override
  void dispose() {
    _phoneController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final normalized = _normalizeIndonesianPhone(_phoneController.text);
    if (normalized == null) {
      setState(
        () => _error =
            'Masukkan nomor HP Indonesia yang valid, misalnya 081234567890.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPhoneOtp(normalized);
      if (!mounted) return;
      setState(() {
        _normalizedPhone = normalized;
        _sent = true;
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'OTP belum dapat dikirim. Periksa koneksi lalu coba lagi.';
      });
    }
  }

  Future<void> _verify() async {
    if (!_sent || _normalizedPhone == null || _verifying) return;
    final token = _tokenController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(token)) {
      setState(() => _error = 'Kode OTP harus terdiri dari 6 digit.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyPhoneOtp(phone: _normalizedPhone!, token: token);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = 'Kode OTP belum benar atau sudah kedaluwarsa.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('OTP nomor HP'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _phoneController,
                enabled: !_sending && !_verifying,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP',
                  hintText: '081234567890',
                ),
                validator: (value) =>
                    _normalizeIndonesianPhone(value ?? '') == null
                    ? 'Masukkan nomor HP Indonesia yang valid'
                    : null,
              ),
              const SizedBox(height: 8),
              if (_sent) ...[
                Text(
                  'Kode OTP dikirim ke nomor yang berakhiran ${_normalizedPhone!.substring(_normalizedPhone!.length - 4)}.',
                  style: AppTextStyles.captionMuted,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tokenController,
                  enabled: !_verifying,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Kode OTP',
                    counterText: '',
                  ),
                ),
                if (_showPreviewCode)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Preview: gunakan kode 246810.'),
                  ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending || _verifying
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        if (!_sent)
          FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kirim OTP'),
          )
        else ...[
          TextButton(
            onPressed: _sending || _verifying ? null : _send,
            child: const Text('Kirim ulang'),
          ),
          FilledButton(
            onPressed: _verifying ? null : _verify,
            child: _verifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verifikasi'),
          ),
        ],
      ],
    );
  }
}

class _ResetPasswordDialog extends ConsumerStatefulWidget {
  const _ResetPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  ConsumerState<_ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<_ResetPasswordDialog> {
  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPasswordForEmail(_emailController.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Permintaan belum dapat diproses. Periksa koneksi lalu coba lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset kata sandi'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan emailmu. Jika akun dengan email tersebut ada, kami akan mengirimkan tautan reset.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) => value == null || !value.contains('@')
                  ? 'Masukkan email yang valid'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Kirim tautan'),
        ),
      ],
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
