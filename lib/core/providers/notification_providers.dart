import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/notification_model.dart';
import '../preview/preview_store.dart';
import 'repository_providers.dart';
import '../session/session_mode.dart';

DateTime _hoursAgo(int hours) =>
    DateTime.now().subtract(Duration(hours: hours));

class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
  NotificationsNotifier({required this.demo, this.uid})
    : super(demo ? _fromStore() : const []) {
    if (demo) {
      _subscription = PreviewStore.changes.listen((_) {
        state = _fromStore();
      });
    } else if (uid != null) {
      try {
        _subscription = Supabase.instance.client
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', uid!)
            .listen((rows) => state = _fromRows(rows));
      } catch (_) {
        _subscription = const Stream<int>.empty().listen((_) {});
      }
    } else {
      _subscription = const Stream<int>.empty().listen((_) {});
    }
  }
  final bool demo;
  final String? uid;
  late final StreamSubscription<dynamic> _subscription;

  static List<NotificationModel> _fromStore() {
    final rows = PreviewStore.notifications;
    if (rows.isEmpty) return _seed;
    return rows
        .map(
          (row) => NotificationModel(
            id: row['id']?.toString() ?? '',
            type: switch (row['kind']?.toString()) {
              'offer' || 'setoran' => NotificationType.setoran,
              'poin' => NotificationType.poin,
              'event' => NotificationType.event,
              _ => NotificationType.sistem,
            },
            title: row['title']?.toString() ?? '',
            body: row['body']?.toString() ?? '',
            createdAt:
                DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now(),
            isRead: row['read'] == true,
          ),
        )
        .toList();
  }

  static List<NotificationModel> _fromRows(List<Map<String, dynamic>> rows) =>
      rows
          .map(
            (row) => NotificationModel(
              id: row['id']?.toString() ?? '',
              type: switch (row['kind']?.toString()) {
                'offer' || 'setoran' => NotificationType.setoran,
                'poin' => NotificationType.poin,
                'event' => NotificationType.event,
                _ => NotificationType.sistem,
              },
              title: row['title']?.toString() ?? '',
              body: row['body']?.toString() ?? '',
              createdAt:
                  DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                  DateTime.now(),
              isRead: row['read_at'] != null,
            ),
          )
          .toList();

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
    if (demo) {
      for (final row in PreviewStore.notifications) {
        row['read'] = true;
      }
      PreviewStore.save();
    }
    if (!demo && uid != null) {
      try {
        Supabase.instance.client
            .from('notifications')
            .update({'read_at': DateTime.now().toUtc().toIso8601String()})
            .eq('user_id', uid!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
      (ref) => NotificationsNotifier(
        demo: ref.watch(sessionModeProvider) == SessionMode.demo,
        uid: ref.watch(currentUidProvider).valueOrNull,
      ),
    );

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.isRead).length;
});
