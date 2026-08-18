import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/preview/preview_mode.dart';
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
      routerConfig: router,
      builder: (context, child) {
        if (!kPreviewMode || child == null) return child ?? const SizedBox();
        return Banner(
          message: 'PRATINJAU',
          location: BannerLocation.topEnd,
          color: Colors.orange,
          child: child,
        );
      },
    );
  }
}
