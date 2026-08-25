import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/preview/preview_mode.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/session/session_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'pengolah_colors.dart';
import 'widgets/pengolah_beranda_tab.dart';
import 'widgets/pengolah_dashboard_tab.dart';
import 'widgets/pengolah_komunitas_tab.dart';
import 'widgets/pengolah_profil_tab.dart';
import 'widgets/pengolah_setoran_tab.dart';

/// Self-contained shell for the "Akun Pengolah" testing account — its own
/// bottom navigation and tab state, entirely separate from the
/// BottomNavScaffold/StatefulShellRoute used by the Sumber role so nothing
/// here touches Sumber code paths.
class PengolahShellScreen extends ConsumerStatefulWidget {
  const PengolahShellScreen({super.key});

  @override
  ConsumerState<PengolahShellScreen> createState() =>
      _PengolahShellScreenState();
}

class _PengolahShellScreenState extends ConsumerState<PengolahShellScreen> {
  int _index = 0;

  Future<void> _keluar() async {
    // The Pengolah testing account is a real signed-in Firebase identity
    // now (see testing_accounts.dart), not just local state — sign out for
    // real too, same as Sumber's own logout does.
    if (!kPreviewMode) {
      await ref.read(authRepositoryProvider).signOut();
    }
    ref.read(sessionModeProvider.notifier).state = SessionMode.normal;
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      PengolahBerandaTab(onNavigate: (i) => setState(() => _index = i)),
      const PengolahDashboardTab(),
      const PengolahSetoranTab(),
      const PengolahKomunitasTab(),
      PengolahProfilTab(onKeluar: _keluar),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: tabs),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Beranda',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Dashboard',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                _NavItem(
                  icon: Icons.inbox_rounded,
                  label: 'Setoran',
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
                _NavItem(
                  icon: Icons.groups_rounded,
                  label: 'Komunitas',
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profil',
                  selected: _index == 4,
                  onTap: () => setState(() => _index = 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? PengolahColors.primary : AppColors.textMuted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.captionMuted.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
