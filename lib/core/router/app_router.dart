import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/submission_model.dart';
import '../../features/articles/article_detail_screen.dart';
import '../../features/articles/article_list_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/home/beranda_screen.dart';
import '../../features/home/level_sirkular_screen.dart';
import '../../features/map/peta_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/pengolah/pengolah_shell_screen.dart';
import '../../features/profile/panduan_screen.dart';
import '../../features/profile/profil_screen.dart';
import '../../features/profile/static_info_screen.dart';
import '../../features/sari_chat/sari_chat_screen.dart';
import '../../features/setor_foto/foto_konfirmasi_screen.dart';
import '../../features/setor_manual/setor_form_screen.dart';
import '../../features/setor_manual/setor_progress_screen.dart';
import '../../features/setor_manual/setoran_status_list_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/wilayah/wilayah_pencocokan_screen.dart';
import '../providers/repository_providers.dart';
import '../session/session_mode.dart';
import '../../shared/widgets/bottom_nav_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Bridges Riverpod state changes to GoRouter's `refreshListenable` so it
/// re-runs `redirect()` on the CURRENT location instead of the router
/// getting rebuilt from scratch. This matters a lot here: [routerProvider]
/// used to `ref.watch` auth/session state directly, which made Riverpod
/// recompute the whole provider — and hand `MaterialApp.router` a brand
/// NEW `GoRouter` instance — on every login/session change. A fresh
/// GoRouter always starts over at `initialLocation: '/splash'`, and
/// `SplashScreen`'s own timer unconditionally does `context.go('/beranda')`
/// with no idea `pengolahDemo` mode exists — so tapping "Masuk sebagai Akun
/// Pengolah (Testing)" would navigate to `/pengolah` for an instant, then
/// get silently bounced back to Sumber's `/beranda` a beat later. Guest and
/// Sumber's own "Akun Testing" never surfaced this because their target
/// (`/beranda`) happens to match Splash's hardcoded one anyway.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(currentUidProvider, (_, _) => notifyListeners());
    ref.listen(sessionModeProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(currentUidProvider);
      final sessionMode = ref.read(sessionModeProvider);
      final isLoggedIn =
          authState.valueOrNull != null || sessionMode != SessionMode.normal;
      final isAuthLoading = authState.isLoading && sessionMode == SessionMode.normal;
      final onSplash = state.matchedLocation == '/splash';
      final onAuthPage = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (onSplash || isAuthLoading) return null;
      if (!isLoggedIn && !onAuthPage) return '/login';
      if (isLoggedIn && onAuthPage) {
        return sessionMode == SessionMode.pengolahDemo ? '/pengolah' : '/beranda';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // Standalone shell for the "Akun Pengolah" testing account — kept
      // fully separate from the Sumber StatefulShellRoute below.
      GoRoute(
        path: '/pengolah',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PengolahShellScreen(),
      ),
      // NOTE: go_router matches sibling routes in declaration order, and
      // `:kategori` matches ANY single segment (including "sukses" or
      // "foto-konfirmasi") — so the literal /setor/... routes below MUST be
      // declared before the /setor/:kategori wildcard, or they'll never be
      // reached (kategori would just be the literal string "sukses" etc.,
      // silently falling back to WasteCategory.organik).
      GoRoute(
        path: '/setor/sukses',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return SetorProgressScreen(initial: state.extra as SubmissionModel);
        },
      ),
      GoRoute(
        path: '/setor/status',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SetoranStatusListScreen(),
      ),
      GoRoute(
        path: '/setor/foto-konfirmasi',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final args = state.extra as FotoDeteksiArgs;
          return FotoKonfirmasiScreen(
            uid: args.uid,
            imagePath: args.imagePath,
            imageBytes: args.imageBytes,
            result: args.result,
          );
        },
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
        path: '/artikel',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ArticleListScreen(),
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
