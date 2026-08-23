import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/preview/preview_store.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/session/session_mode.dart';
import 'admin_role_screen.dart';
import 'dlh_role_screen.dart';
import 'pengolah_role_screen.dart';
import 'sumber_role_screen.dart';

const _roleLabels = {
  'sumber': 'Sumber',
  'pengolah': 'Pengolah',
  'dlh': 'DLH',
  'admin': 'Admin',
};

class RoleShellScreen extends ConsumerStatefulWidget {
  const RoleShellScreen({super.key});
  @override
  ConsumerState<RoleShellScreen> createState() => _RoleShellScreenState();
}

class _RoleShellScreenState extends ConsumerState<RoleShellScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final isDemo = ref.watch(sessionModeProvider) == SessionMode.demo;
    final profileState = ref.watch(userProfileProvider);
    if (!isDemo && profileState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!isDemo &&
        (profileState.hasError || profileState.valueOrNull == null)) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Profil akun belum tersedia. Hubungi Admin untuk provisioning role.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }
    final role = isDemo
        ? ref.watch(previewRoleProvider)
        : profileState.valueOrNull!.primaryRole;
    final tabs = switch (role) {
      'pengolah' => [
        'Dashboard',
        'Permintaan',
        'Pickup',
        'Kapasitas',
        'Profil',
      ],
      'dlh' => ['Dashboard', 'Wilayah', 'Laporan', 'Profil'],
      'admin' => ['Antrean', 'Transaksi', 'Redeem', 'Audit', 'Profil'],
      _ => ['Beranda', 'Riwayat', 'Sari', 'Poin', 'Profil'],
    };
    final activeTab = tab >= tabs.length ? 0 : tab;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_roleLabels[role] ?? 'Sumber'}${isDemo ? ' · Preview' : ''}',
        ),
        actions: [
          if (isDemo)
            PopupMenuButton<String>(
              tooltip: 'Ganti peran Preview',
              icon: const Icon(Icons.switch_account_outlined),
              onSelected: (value) async {
                await PreviewStore.setRole(value);
                ref.read(previewRoleProvider.notifier).state = value;
                setState(() => tab = 0);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'sumber', child: Text('Sumber · Bu Siti')),
                PopupMenuItem(
                  value: 'pengolah',
                  child: Text('Pengolah · Pak Bambang'),
                ),
                PopupMenuItem(value: 'dlh', child: Text('DLH Semarang')),
                PopupMenuItem(value: 'admin', child: Text('Admin SisaPedia')),
              ],
            ),
          if (isDemo)
            IconButton(
              tooltip: 'Reset demo',
              icon: const Icon(Icons.restart_alt),
              onPressed: () async {
                await PreviewStore.reset();
                ref.read(previewRoleProvider.notifier).state = 'sumber';
                if (mounted) setState(() => tab = 0);
              },
            ),
        ],
      ),
      body: _roleBody(role, activeTab),
      bottomNavigationBar: NavigationBar(
        selectedIndex: activeTab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: [
          for (final label in tabs)
            NavigationDestination(icon: Icon(_icon(label)), label: label),
        ],
      ),
    );
  }

  Widget _roleBody(String role, int activeTab) => switch (role) {
    'pengolah' => PengolahRoleScreen(tab: activeTab),
    'dlh' => DlhRoleScreen(tab: activeTab),
    'admin' => AdminRoleScreen(tab: activeTab),
    _ => SumberRoleScreen(tab: activeTab),
  };

  IconData _icon(String label) => switch (label) {
    'Dashboard' => Icons.dashboard_outlined,
    'Beranda' => Icons.home_outlined,
    'Riwayat' => Icons.history,
    'Sari' => Icons.mic_none,
    'Poin' => Icons.stars_outlined,
    'Profil' => Icons.person_outline,
    'Permintaan' => Icons.inbox_outlined,
    'Pickup' => Icons.local_shipping_outlined,
    'Kapasitas' => Icons.inventory_2_outlined,
    'Wilayah' => Icons.map_outlined,
    'Laporan' => Icons.assessment_outlined,
    'Antrean' => Icons.pending_actions,
    'Transaksi' => Icons.receipt_long,
    'Redeem' => Icons.redeem,
    'Audit' => Icons.security,
    String() => Icons.circle_outlined,
  };
}
