import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/notification_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/session/session_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/movement_event_model.dart';
import 'widgets/beranda_header.dart';
import 'widgets/history_section.dart';
import 'widgets/join_event_sheet.dart';
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
    await ref
        .read(pointsRepositoryProvider)
        .requestRedeem(uid: uid, jumlah: jumlah, deskripsi: deskripsi);
    if (context.mounted) {
      _showSnack(context, 'Permintaan diajukan, diproses admin.');
    }
  }

  void _openRedeemSheet(
    BuildContext context,
    WidgetRef ref,
    String uid,
    int currentPoin,
  ) {
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
                leading: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Cairkan Poin ke Dana/OVO'),
                subtitle: const Text('Min. 500 poin sirkular'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _handleRedeem(
                    context,
                    ref,
                    uid,
                    currentPoin,
                    500,
                    'Cairkan Poin ke Dana/OVO',
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.card_giftcard_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Voucher Kompos Organik'),
                subtitle: const Text('Dari mitra Kompos Tandur Ijo · 300 poin'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _handleRedeem(
                    context,
                    ref,
                    uid,
                    currentPoin,
                    300,
                    'Voucher Kompos Organik',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleJoinEvent(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String userName,
    MovementEventModel event,
  ) {
    showJoinEventSheet(
      context,
      eventTitle: event.title,
      organizer: event.organizer,
      defaultName: userName,
      onSubmit: (result) async {
        await ref
            .read(contentRepositoryProvider)
            .joinEvent(eventId: event.id, uid: uid);
        if (context.mounted) {
          _showSnack(
            context,
            'Pendaftaran ke ${event.title} diajukan ke ${event.organizer}.',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final isGuest = ref.watch(sessionModeProvider) == SessionMode.guest;
    final uid =
        ref.watch(currentUidProvider).valueOrNull ??
        (isGuest ? kGuestUid : null);

    if (uid == null || profileAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profile = profileAsync.valueOrNull;
    final poin = profile?.poinSirkular ?? 0;
    final hasUnread = ref.watch(unreadNotificationsCountProvider) > 0;

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
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  BerandaHeader(
                    profile: profile,
                    hasUnreadNotifications: hasUnread,
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: -60,
                    child: PointsCard(
                      poin: poin,
                      onTukar: () => _openRedeemSheet(context, ref, uid, poin),
                      onLihatRiwayat: () => context.push('/level-sirkular'),
                    ),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 68, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SetorActionsSection(
                    onSetorOrganik: () => context.push('/setor/organik'),
                    onSetorAnorganik: () => context.push('/setor/anorganik'),
                    onWilayahPencocokan: () =>
                        context.push('/wilayah-pencocokan'),
                  ),
                  const SizedBox(height: 24),
                  RedeemArticleSection(
                    onRedeem: (jumlah, deskripsi) => _handleRedeem(
                      context,
                      ref,
                      uid,
                      poin,
                      jumlah,
                      deskripsi,
                    ),
                  ),
                  const SizedBox(height: 24),
                  MovementSection(
                    onJoin: (event) => _handleJoinEvent(
                      context,
                      ref,
                      uid,
                      profile?.name ?? '',
                      event,
                    ),
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
