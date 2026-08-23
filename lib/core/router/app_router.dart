import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/submission_model.dart';
import '../../features/articles/article_detail_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/home/beranda_screen.dart';
import '../../features/home/level_sirkular_screen.dart';
import '../../features/map/peta_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/panduan_screen.dart';
import '../../features/profile/profil_screen.dart';
import '../../features/profile/static_info_screen.dart';
import '../../features/sari_chat/sari_chat_screen.dart';
import '../../features/setor_manual/setor_form_screen.dart';
import '../../features/setor_manual/setor_success_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/wilayah/wilayah_pencocokan_screen.dart';
import '../../features/wilayah/candidate_selection_screen.dart';
import '../../features/roles/role_shell_screen.dart';
import '../providers/repository_providers.dart';
import '../session/session_mode.dart';
import '../../shared/widgets/bottom_nav_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUidProvider);
  final sessionMode = ref.watch(sessionModeProvider);
  final profileState = ref.watch(userProfileProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isLoggedIn =
          authState.valueOrNull != null || sessionMode != SessionMode.normal;
      final isAuthLoading =
          authState.isLoading && sessionMode == SessionMode.normal;
      final onSplash = state.matchedLocation == '/splash';
      final onAuthPage =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (onSplash || isAuthLoading) return null;
      if (!isLoggedIn && !onAuthPage) return '/login';
      if (isLoggedIn && onAuthPage) return '/role';
      final role = sessionMode == SessionMode.demo
          ? ref.read(previewRoleProvider)
          : profileState.valueOrNull?.primaryRole;
      final sourceOnly =
          state.matchedLocation == '/sari-chat' ||
          state.matchedLocation == '/beranda' ||
          state.matchedLocation == '/peta' ||
          state.matchedLocation == '/dashboard' ||
          state.matchedLocation == '/profil' ||
          state.matchedLocation == '/wilayah-pencocokan' ||
          state.matchedLocation == '/level-sirkular' ||
          state.matchedLocation.startsWith('/setor/');
      if (sourceOnly && role != null && role != 'sumber') {
        return '/role';
      }
      if (state.matchedLocation.startsWith('/setor/') &&
          role != null &&
          role != 'sumber') {
        return '/role';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/role',
        builder: (context, state) => const RoleShellScreen(),
      ),
      GoRoute(
        path: '/setor/:kategori',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final kategori = state.pathParameters['kategori'] == 'anorganik'
              ? WasteCategory.anorganik
              : WasteCategory.organik;
          final extra = state.extra;
          return SetorFormScreen(
            kategori: kategori,
            prefill: extra is WastePrefill ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/setor/sukses',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return SetorSuccessScreen(submission: state.extra as SubmissionModel);
        },
      ),
      GoRoute(
        path: '/profil/info/:slug',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          if (slug == 'panduan') return const PanduanScreen();
          return StaticInfoScreen(slug: slug);
        },
      ),
      GoRoute(
        path: '/wilayah-pencocokan',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WilayahPencocokanScreen(),
      ),
      GoRoute(
        path: '/setor/:id/kandidat',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            CandidateSelectionScreen(submissionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/level-sirkular',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LevelSirkularScreen(),
      ),
      GoRoute(
        path: '/sari-chat',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SariChatScreen(),
      ),
      GoRoute(
        path: '/artikel/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return ArticleDetailScreen(articleId: state.pathParameters['id']!);
        },
      ),
      GoRoute(
        path: '/notifikasi',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => BottomNavScaffold(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/beranda',
                builder: (context, state) => const BerandaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/peta',
                builder: (context, state) => const PetaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profil',
                builder: (context, state) => const ProfilScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
