import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_model.dart';
import '../preview/preview_mode.dart';
import '../session/session_mode.dart';
import 'repository_providers.dart';

DateTime _hoursAgo(int hours) =>
    DateTime.now().subtract(Duration(hours: hours));

class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
  NotificationsNotifier() : super(_seed);

  static final _seed = <NotificationModel>[
    NotificationModel(
      id: 'n1',
      type: NotificationType.setoran,
      title: 'Setoran Anorganik terverifikasi',
      body:
          'Pengepul Jaya sudah memverifikasi setoran Botol Plastik PET 1,1 kg milikmu.',
      createdAt: _hoursAgo(2),
    ),
    NotificationModel(
      id: 'n2',
      type: NotificationType.poin,
      title: 'Poin Sirkular bertambah',
      body: 'Kamu dapat +36 Poin Sirkular dari setoran Sisa Sayur & Buah.',
      createdAt: _hoursAgo(9),
    ),
    NotificationModel(
      id: 'n3',
      type: NotificationType.event,
      title: 'Event baru di dekatmu',
      body:
          'Bank Sampah Melati Bersih mengadakan Panen Maggot Bersama Warga, 6 hari lagi.',
      createdAt: _hoursAgo(30),
      isRead: true,
    ),
    NotificationModel(
      id: 'n4',
      type: NotificationType.sistem,
      title: 'Jadwal jemput diperbarui',
      body:
          'Wilayah Tembalang kini punya slot penjemputan tambahan setiap Sabtu pagi.',
      createdAt: _hoursAgo(72),
      isRead: true,
    ),
  ];

  void markAllRead() {
    state = [for (final n in state) n.copyWith(isRead: true)];
  }
}

/// Static local seed — used for guest sessions and `kPreviewMode` builds,
/// where there's no real backend to notify from.
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
        (ref) => NotificationsNotifier());

NotificationType _typeFromString(String? value) {
  return NotificationType.values.firstWhere((e) => e.name == value,
      orElse: () => NotificationType.sistem);
}

/// Real notifications for the connected "Akun Testing" (Sumber) flow (26
/// Agustus 2026) — written by `SubmissionFlowService` on the Pengolah side
/// whenever the shared submission's state changes. Sorted client-side (not
/// `.orderBy()`) to avoid needing a composite Firestore index for a plain
/// equality-filtered query.
final _firestoreNotificationsProvider =
    StreamProvider<List<NotificationModel>>((ref) {
  final uid = ref.watch(currentUidProvider).valueOrNull;
  if (uid == null) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((snap) {
    final items = snap.docs.map((d) {
      final data = d.data();
      return NotificationModel(
        id: d.id,
        type: _typeFromString(data['type'] as String?),
        title: data['title'] as String? ?? '',
        body: data['body'] as String? ?? '',
        createdAt:
            (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        isRead: data['read'] as bool? ?? false,
      );
    }).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  });
});

/// What [NotificationsScreen] and the Beranda bell badge should actually
/// read — real Firestore notifications for the connected Sumber testing
/// account, the static local seed for everyone else (guest/normal/preview).
final notificationsListProvider = Provider<List<NotificationModel>>((ref) {
  final connected =
      !kPreviewMode && ref.watch(sessionModeProvider) == SessionMode.demo;
  if (connected) {
    return ref.watch(_firestoreNotificationsProvider).valueOrNull ?? const [];
  }
  return ref.watch(notificationsProvider);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsListProvider).where((n) => !n.isRead).length;
});

/// Marks every notification read — Firestore batch for the connected flow,
/// local state mutation otherwise. Call from [NotificationsScreen].
/// Takes `WidgetRef` (not `Ref`) since it's only ever called from a screen.
Future<void> markAllNotificationsRead(WidgetRef ref) async {
  final connected =
      !kPreviewMode && ref.read(sessionModeProvider) == SessionMode.demo;
  if (connected) {
    final uid = ref.read(currentUidProvider).valueOrNull;
    if (uid == null) return;
    final unread = await FirebaseFirestore.instance
        .collection('notifications')
        .where('uid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
    return;
  }
  ref.read(notificationsProvider.notifier).markAllRead();
}
