import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_store_provider.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../shared/models/notification.dart';
import '../../shared/widgets/brand.dart';
import '../auth/auth_controller.dart';

final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return ref.watch(demoStoreProvider).notifications;
  }
  final user = ref.watch(authControllerProvider);
  if (user == null) return const [];
  final rows = await client
      .from('notifications')
      .select()
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .limit(50);
  return (rows as List)
      .map((r) => AppNotification.fromMap(r as Map<String, dynamic>))
      .toList();
});

/// Unread badge count (kept cheap for the profile tile).
final unreadCountProvider = Provider<int>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return ref.watch(demoStoreProvider).unreadCount;
  return ref
          .watch(notificationsProvider)
          .valueOrNull
          ?.where((n) => !n.read)
          .length ??
      0;
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllRead(WidgetRef ref) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      ref.read(demoStoreProvider).markAllNotificationsRead();
      return;
    }
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    await client
        .from('notifications')
        .update({'read': true})
        .eq('user_id', user.id)
        .eq('read', false);
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final notifs = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('notif.title')),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(ref),
            child: Text(s.t('notif.markRead')),
          ),
        ],
      ),
      body: notifs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            EmptyState(title: s.t('detail.loadError'), subtitle: '$e'),
        data: (list) => list.isEmpty
            ? EmptyState(
                title: s.t('notif.empty'),
                subtitle: s.t('notif.emptySub'),
                icon: Icons.notifications_none,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _NotifTile(n: list[i]),
              ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.n});
  final AppNotification n;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.violet.withValues(alpha: 0.2),
          child: Icon(n.kind.icon, color: AppColors.cyan, size: 20),
        ),
        title: Text(n.title,
            style: TextStyle(
                fontWeight: n.read ? FontWeight.w500 : FontWeight.w800)),
        subtitle: n.body == null ? null : Text(n.body!),
        trailing: Text(Format.date(n.createdAt),
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ),
    );
  }
}
