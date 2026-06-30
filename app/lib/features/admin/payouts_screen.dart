import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_store_provider.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../shared/models/payout.dart';
import '../../shared/widgets/brand.dart';

final payoutsProvider = FutureProvider<List<Payout>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return ref.watch(demoStoreProvider).payouts;

  final rows = await client
      .from('payouts')
      .select('id, user_id, amount, status, competitions(title)')
      .order('created_at', ascending: false);
  final list = rows;
  final userIds =
      list.map((r) => r['user_id'] as String).toSet().toList();
  final profRows = userIds.isEmpty
      ? const []
      : await client
          .from('profiles')
          .select('id, display_name')
          .inFilter('id', userIds);
  final names = {
    for (final p in profRows)
      p['id'] as String: (p['display_name'] ?? 'Player') as String
  };
  return list.map((r) {
    final comp = r['competitions'];
    return Payout(
      id: r['id'] as String,
      userId: r['user_id'] as String,
      userName: names[r['user_id']] ?? 'Player',
      competitionId: '',
      competitionTitle:
          comp is Map ? (comp['title'] ?? 'Competition') as String : 'Competition',
      amount: (r['amount'] ?? 0) as int,
      status: PayoutStatus.fromString(r['status'] as String?),
    );
  }).toList();
});

class AdminPayoutsScreen extends ConsumerWidget {
  const AdminPayoutsScreen({super.key});

  Future<void> _markPaid(WidgetRef ref, Payout p) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      ref.read(demoStoreProvider).markPayoutPaid(p.id);
      return;
    }
    await client.from('payouts').update({
      'status': 'paid',
      'paid_at': DateTime.now().toIso8601String(),
    }).eq('id', p.id);
    ref.invalidate(payoutsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final payouts = ref.watch(payoutsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('admin.payouts'))),
      body: payouts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            EmptyState(title: s.t('detail.loadError'), subtitle: '$e'),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              title: s.t('admin.payoutsEmpty'),
              subtitle: s.t('admin.payoutsEmptySub'),
              icon: Icons.account_balance_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final p = list[i];
              final paid = p.status == PayoutStatus.paid;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                    child: const Icon(Icons.emoji_events, color: AppColors.gold),
                  ),
                  title: Text('${p.userName} · ${Format.rupiah(p.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(p.competitionTitle),
                  trailing: paid
                      ? TagPill(s.t('admin.paid'), color: AppColors.success)
                      : FilledButton(
                          onPressed: () => _markPaid(ref, p),
                          child: Text(s.t('admin.markPaid')),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
