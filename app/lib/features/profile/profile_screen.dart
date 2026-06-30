import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../shared/models/app_user.dart';
import '../../shared/widgets/brand.dart';
import '../auth/auth_controller.dart';
import '../notifications/notifications_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final user = ref.watch(authControllerProvider);
    if (user == null) {
      return Scaffold(body: EmptyState(title: s.t('profile.notSignedIn')));
    }
    final unread = ref.watch(unreadCountProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('profile.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.violet.withValues(alpha: 0.25),
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(user.email,
                        style: const TextStyle(color: Colors.white54)),
                    const SizedBox(height: 6),
                    TagPill(user.role.label,
                        color: user.role == UserRole.admin
                            ? AppColors.gold
                            : AppColors.cyan),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Tile(
            icon: Icons.account_balance_wallet_outlined,
            title: s.t('profile.payouts'),
            subtitle: s.t('profile.payoutsSub'),
            onTap: () => context.push('/payout'),
          ),
          _Tile(
            icon: Icons.emoji_events_outlined,
            title: s.t('profile.myRegistrations'),
            subtitle: s.t('profile.myRegistrationsSub'),
            onTap: () => context.push('/my-registrations'),
          ),
          _Tile(
            icon: Icons.notifications_outlined,
            title: s.t('profile.notifications'),
            subtitle: s.t('profile.notificationsSub'),
            trailing: unread > 0
                ? TagPill('$unread', color: AppColors.danger)
                : null,
            onTap: () => context.push('/notifications'),
          ),
          _Tile(
            icon: Icons.language_outlined,
            title: s.t('profile.settings'),
            subtitle: s.t('profile.settingsSub'),
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: Text(s.t('profile.signOut')),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(icon, color: AppColors.cyan),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
