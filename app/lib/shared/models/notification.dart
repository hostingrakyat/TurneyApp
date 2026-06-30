import 'package:flutter/material.dart';

enum NotificationKind {
  payment,
  match,
  dispute,
  payout,
  system;

  static NotificationKind fromString(String? v) =>
      NotificationKind.values.firstWhere((e) => e.name == v,
          orElse: () => NotificationKind.system);

  IconData get icon => switch (this) {
        NotificationKind.payment => Icons.payments_outlined,
        NotificationKind.match => Icons.sports_esports_outlined,
        NotificationKind.dispute => Icons.gavel_outlined,
        NotificationKind.payout => Icons.emoji_events_outlined,
        NotificationKind.system => Icons.notifications_outlined,
      };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    this.body,
    this.read = false,
    required this.createdAt,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String? body;
  final bool read;
  final DateTime createdAt;

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        kind: NotificationKind.fromString(m['kind'] as String?),
        title: (m['title'] ?? '') as String,
        body: m['body'] as String?,
        read: (m['read'] ?? false) as bool,
        createdAt: m['created_at'] == null
            ? DateTime.now()
            : DateTime.parse(m['created_at'] as String),
      );
}
