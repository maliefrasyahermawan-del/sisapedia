import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_model.dart';

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

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
        (ref) => NotificationsNotifier());

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.isRead).length;
});
