import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/points_transaction_model.dart';
import '../setor_cerdas/voice_modal.dart';
import 'widgets/beranda_header.dart';
import 'widgets/history_section.dart';
import 'widgets/movement_section.dart';
import 'widgets/points_card.dart';
import 'widgets/redeem_article_section.dart';
import 'widgets/setor_actions_section.dart';

class BerandaScreen extends ConsumerWidget {
  const BerandaScreen({super.key});

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleRedeem(
    BuildContext context,
    WidgetRef ref,
    String uid,
    int currentPoin,
    int jumlah,
    String deskripsi,
  ) async {
    if (currentPoin < jumlah) {
      _showSnack(context, 'Poin sirkular kamu belum cukup untuk ini.');
      return;
    }
    await ref.read(pointsRepositoryProvider).requestRedeem(
          uid: uid,
          jumlah: jumlah,
          deskripsi: deskripsi,
        );
    if (context.mounted) {
      _showSnack(context, 'Permintaan diajukan, diproses admin.');
    }
  }

  void _openRedeemSheet(
      BuildContext context, WidgetRef ref, String uid, int currentPoin) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tukar Poin Sirkular', style: AppTextStyles.h2),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.primary),
                title: const Text('Cairkan Poin ke Dana/OVO'),
                subtitle: const Text('Min. 500 poin sirkular'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _handleRedeem(context, ref, uid, currentPoin, 500,
                      'Cairkan Poin ke Dana/OVO');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.card_giftcard_rounded,
                    color: AppColors.primary),
                title: const Text('Voucher Kompos Organik'),
                subtitle: const Text('Dari mitra Kompos Tandur Ijo · 300 poin'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _handleRedeem(context, ref, uid, currentPoin, 300,
                      'Voucher Kompos Organik');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRiwayatPoinSheet(BuildContext context, WidgetRef ref, String uid,
      String levelTitle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final txAsync = ref.watch(userPointsTransactionsProvider(uid));
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(levelTitle, style: AppTextStyles.h2),
                const SizedBox(height: 4),
                Text('Riwayat poin sirkular kamu', style: AppTextStyles.captionMuted),
                const SizedBox(height: 12),
                Expanded(
                  child: txAsync.when(
                    data: (txs) {
                      if (txs.isEmpty) {
                        return Center(
                          child: Text('Belum ada riwayat poin.',
                              style: AppTextStyles.captionMuted),
                        );
                      }
                      return ListView.separated(
                        controller: scrollController,
                        itemCount: txs.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, i) {
                          final tx = txs[i];
                          final isEarn =
                              tx.jenis == PointsTransactionType.earn;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(tx.deskripsi),
                            subtitle: Text(tx.status.label),
                            trailing: Text(
                              '${isEarn ? '+' : '-'}${tx.jumlah}',
                              style: AppTextStyles.bodyBold.copyWith(
                                color: isEarn
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(
                        child: Text('Gagal memuat riwayat.',
                            style: AppTextStyles.captionMuted)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final uid = ref.watch(currentUidProvider).valueOrNull;

    if (uid == null || profileAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profile = profileAsync.valueOrNull;
    final poin = profile?.poinSirkular ?? 0;
    final levelTitle = profile?.levelTitle ?? 'Pejuang Kota Sirkular';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userSubmissionsProvider(uid));
          ref.invalidate(articlesProvider);
          ref.invalidate(movementEventsProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: BerandaHeader(profile: profile)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: PointsCard(
                      poin: poin,
                      onShare: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Bagikan Poin Sirkular'),
                          content: Text(
                            'Aku sudah kumpulkan ${NumberFormat.decimalPattern('id_ID').format(poin)} '
                            'Poin Sirkular di SisaPedia! Yuk kelola sampah bareng.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Tutup'),
                            ),
                          ],
                        ),
                      ),
                      onTukar: () =>
                          _openRedeemSheet(context, ref, uid, poin),
                      onLihatRiwayat: () => _openRiwayatPoinSheet(
                          context, ref, uid, levelTitle),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SetorActionsSection(
                    onSetorCerdas: () => showVoiceModal(context, ref, uid),
                    onSetorOrganik: () => context.push('/setor/organik'),
                    onSetorAnorganik: () => context.push('/setor/anorganik'),
                    onWilayahPencocokan: () => context.go('/peta'),
                  ),
                  const SizedBox(height: 24),
                  RedeemArticleSection(
                    onRedeem: (jumlah, deskripsi) => _handleRedeem(
                        context, ref, uid, poin, jumlah, deskripsi),
                  ),
                  const SizedBox(height: 24),
                  MovementSection(
                    onJoin: (eventId, title) async {
                      await ref
                          .read(contentRepositoryProvider)
                          .joinEvent(eventId: eventId, uid: uid);
                      if (context.mounted) {
                        _showSnack(context, 'Berhasil gabung ke $title');
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  HistorySection(uid: uid),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
