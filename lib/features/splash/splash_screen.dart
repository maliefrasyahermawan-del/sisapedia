import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      // Must match sessionMode here, not hardcode '/beranda' — Pengolah's
      // shell lives at a different route, and go_router's `redirect` only
      // steps in when leaving an auth page, not when landing on the
      // "wrong" home for the current mode (see the comment on
      // `_RouterRefreshNotifier` in app_router.dart for the full story).
      final mode = ref.read(sessionModeProvider);
      context.go(mode == SessionMode.pengolahDemo ? '/pengolah' : '/beranda');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Image.asset('assets/icon/app_icon.png'),
            ),
            const SizedBox(height: 20),
            Text('SisaPedia',
                style: AppTextStyles.h1.copyWith(
                  color: Colors.white,
                  fontSize: 26,
                )),
            const SizedBox(height: 6),
            Text('Kelola sampah, tumbuhkan dampak sirkular',
                style: AppTextStyles.body
                    .copyWith(color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
      ),
    );
  }
}
