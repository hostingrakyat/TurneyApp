import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_settings.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../shared/widgets/brand.dart';
import '../competitions/competitions_controller.dart';
import '../matches/matches_controller.dart';

/// Lightweight admin overview. Full user/dispute/payout management arrives in
/// Phase 4 — this gives admins a live snapshot on both web and mobile.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final comps = ref.watch(competitionsControllerProvider);
    final disputes = ref.watch(disputedMatchesProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(s.t('admin.title'))),
      body: comps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            EmptyState(title: s.t('admin.loadError'), subtitle: '$e'),
        data: (all) {
          final players =
              all.fold<int>(0, (s, c) => s + c.participantCount);
          final gross =
              all.fold<int>(0, (s, c) => s + c.participantCount * c.entryFee);
          final platformEarnings = (gross * 0.1).round();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GradientPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t('admin.earnings'),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(Format.rupiah(platformEarnings),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.emoji_events,
                      label: s.t('admin.competitions'),
                      value: '${all.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.group,
                      label: s.t('admin.registrations'),
                      value: '$players',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.payments,
                      label: s.t('admin.grossVolume'),
                      value: Format.rupiah(gross),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.gavel,
                      label: s.t('admin.openDisputes'),
                      value: '${disputes.length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(s.t('admin.appSettings'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const _AdminSettingsCard(),
              const SizedBox(height: 12),
              _AdminLink(
                icon: Icons.tune,
                title: s.t('admin.config'),
                onTap: () => context.push('/admin/config'),
              ),
              _AdminLink(
                icon: Icons.people_alt,
                title: s.t('admin.users'),
                onTap: () => context.push('/admin/users'),
              ),
              _AdminLink(
                icon: Icons.account_balance,
                title: s.t('admin.payouts'),
                onTap: () => context.push('/admin/payouts'),
              ),
              const SizedBox(height: 20),
              Text(s.t('admin.disputes'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (disputes.isEmpty)
                _AdminLink(
                    icon: Icons.verified, title: s.t('admin.noDisputes'))
              else
                ...disputes.map((m) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading:
                            const Icon(Icons.gavel, color: AppColors.danger),
                        title: Text(
                            '${m.player1Name ?? 'Player 1'} vs ${m.player2Name ?? 'Player 2'}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(s.t('admin.tapResolve')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/match/${m.id}'),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.cyan, size: 20),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _AdminLink extends StatelessWidget {
  const _AdminLink({required this.icon, required this.title, this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppColors.violet),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Admin app settings: change the logo + toggle demo mode.
class _AdminSettingsCard extends ConsumerWidget {
  const _AdminSettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(appSettingsProvider);
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            value: settings.demoMode,
            onChanged: (v) =>
                ref.read(appSettingsServiceProvider).setDemoMode(v),
            secondary:
                const Icon(Icons.science_outlined, color: AppColors.gold),
            title: Text(s.t('admin.demoMode'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(s.t('admin.demoModeSub')),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.image_outlined, color: AppColors.cyan),
            title: Text(s.t('admin.changeLogo'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(settings.hasLogoOverride
                ? s.t('admin.logoSet')
                : s.t('admin.logoUpload')),
            trailing: const Icon(Icons.upload),
            onTap: () async {
              final x =
                  await ImagePicker().pickImage(source: ImageSource.gallery);
              if (x == null) return;
              final bytes = await x.readAsBytes();
              await ref.read(appSettingsServiceProvider).setLogo(bytes);
            },
          ),
        ],
      ),
    );
  }
}
