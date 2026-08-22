import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/setor_cerdas/voice_modal.dart';

class BottomNavScaffold extends ConsumerWidget {
  const BottomNavScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _items = [
    (icon: Icons.home_rounded, label: 'Beranda'),
    (icon: Icons.map_rounded, label: 'Peta'),
    (icon: Icons.bar_chart_rounded, label: 'Dashboard'),
    (icon: Icons.person_rounded, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider).valueOrNull;

    return Scaffold(
      body: shell,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sari-chat'),
        backgroundColor: AppColors.textPrimary,
        icon: const Icon(Icons.auto_awesome_rounded,
            color: Colors.white, size: 18),
        label: const Text('Sari', style: TextStyle(color: Colors.white)),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 68,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _NavItem(
                        icon: _items[0].icon,
                        label: _items[0].label,
                        selected: shell.currentIndex == 0,
                        onTap: () => shell.goBranch(0,
                            initialLocation: shell.currentIndex == 0),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: _items[1].icon,
                        label: _items[1].label,
                        selected: shell.currentIndex == 1,
                        onTap: () => shell.goBranch(1,
                            initialLocation: shell.currentIndex == 1),
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                    Expanded(
                      child: _NavItem(
                        icon: _items[2].icon,
                        label: _items[2].label,
                        selected: shell.currentIndex == 2,
                        onTap: () => shell.goBranch(2,
                            initialLocation: shell.currentIndex == 2),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: _items[3].icon,
                        label: _items[3].label,
                        selected: shell.currentIndex == 3,
                        onTap: () => shell.goBranch(3,
                            initialLocation: shell.currentIndex == 3),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: -22,
                  child: Center(
                    child: _SetorCerdasButton(
                      onTap: uid == null
                          ? null
                          : () => showVoiceModal(context, ref, uid),
                    ),
                  ),
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
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.captionMuted.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _SetorCerdasButton extends StatelessWidget {
  const _SetorCerdasButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            'Setor Cerdas',
            style: AppTextStyles.captionMuted
                .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
