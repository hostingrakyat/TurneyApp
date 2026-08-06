import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_settings.dart';
import '../../core/env.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_loader.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/surface.dart';
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
        loading: () => const AppLoading(),
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
              if (Env.paymentsEnabled) ...[
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
              ],
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
                  if (Env.paymentsEnabled) ...[
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.payments,
                        label: s.t('admin.grossVolume'),
                        value: Format.rupiah(gross),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
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
                icon: Icons.emoji_events_outlined,
                title: s.t('mod.title'),
                onTap: () => context.push('/admin/competitions'),
              ),
              // Money surfaces — hidden in store builds (Env.storeBuild).
              if (Env.paymentsEnabled) ...[
                _AdminLink(
                  icon: Icons.receipt_long,
                  title: s.t('txn.title'),
                  onTap: () => context.push('/admin/transactions'),
                ),
                _AdminLink(
                  icon: Icons.account_balance_wallet,
                  title: s.t('pay.accountsTitle'),
                  onTap: () => context.push('/admin/payment-accounts'),
                ),
              ],
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
              if (Env.paymentsEnabled)
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
    return PanelSurface(
      radius: 20,
      pattern: PatternType.dots,
      patternOpacity: 0.14,
      patternSpacing: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.cyan, size: 18),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Colors.white54)),
          ],
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
