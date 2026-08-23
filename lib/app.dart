import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class SisaPediaApp extends ConsumerWidget {
  const SisaPediaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SisaPedia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Keep edge scrolling stable on Android. Material 3's default
      // StretchingOverscrollIndicator makes the whole screen appear to
      // deform when a user reaches the end of a list or form.
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        overscroll: false,
        physics: const ClampingScrollPhysics(),
      ),
      routerConfig: router,
    );
  }
}
