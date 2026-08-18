import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/submission_model.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/home/beranda_screen.dart';
import '../../features/map/peta_screen.dart';
import '../../features/profile/profil_screen.dart';
import '../../features/profile/static_info_screen.dart';
import '../../features/setor_manual/setor_form_screen.dart';
import '../providers/repository_providers.dart';
import '../../shared/widgets/bottom_nav_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUidProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/beranda',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthLoading = authState.isLoading;
      final onAuthPage = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (isAuthLoading) return null;
      if (!isLoggedIn && !onAuthPage) return '/login';
      if (isLoggedIn && onAuthPage) return '/beranda';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/setor/:kategori',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final kategori = state.pathParameters['kategori'] == 'anorganik'
              ? WasteCategory.anorganik
              : WasteCategory.organik;
          return SetorFormScreen(kategori: kategori);
        },
      ),
      GoRoute(
        path: '/profil/info/:slug',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return StaticInfoScreen(slug: state.pathParameters['slug']!);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => BottomNavScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/beranda',
              builder: (context, state) => const BerandaScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/peta',
              builder: (context, state) => const PetaScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profil',
              builder: (context, state) => const ProfilScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});
