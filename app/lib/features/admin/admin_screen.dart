import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
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
    final comps = ref.watch(competitionsControllerProvider);
    final disputes = ref.watch(disputedMatchesProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Admin console')),
      body: comps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(title: 'Could not load', subtitle: '$e'),
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
                    const Text('Platform earnings (10%)',
                        style: TextStyle(
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
                      label: 'Competitions',
                      value: '${all.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.group,
                      label: 'Registrations',
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
                      label: 'Gross volume',
                      value: Format.rupiah(gross),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.gavel,
                      label: 'Open disputes',
                      value: '${disputes.length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Dispute resolution',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (disputes.isEmpty)
                const _AdminLink(
                    icon: Icons.verified, title: 'No open disputes')
              else
                ...disputes.map((m) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.gavel, color: AppColors.danger),
                        title: Text(
                            '${m.player1Name ?? 'Player 1'} vs ${m.player2Name ?? 'Player 2'}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Players disagree — tap to resolve'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/match/${m.id}'),
                      ),
                    )),
              const SizedBox(height: 12),
              const _AdminLink(
                  icon: Icons.people_alt, title: 'Users & roles', soon: true),
              const _AdminLink(
                  icon: Icons.account_balance,
                  title: 'Payout requests',
                  soon: true),
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
  const _AdminLink(
      {required this.icon, required this.title, this.soon = false});
  final IconData icon;
  final String title;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppColors.violet),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: soon
            ? const TagPill('Phase 4', color: Colors.white24)
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
