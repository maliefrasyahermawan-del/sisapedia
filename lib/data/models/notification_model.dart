import 'package:flutter/material.dart';

enum NotificationType { setoran, poin, event, sistem }

extension NotificationTypeX on NotificationType {
  IconData get icon {
    switch (this) {
      case NotificationType.setoran:
        return Icons.check_circle_rounded;
      case NotificationType.poin:
        return Icons.stars_rounded;
      case NotificationType.event:
        return Icons.groups_rounded;
      case NotificationType.sistem:
        return Icons.campaign_rounded;
    }
  }
}

class NotificationModel {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
