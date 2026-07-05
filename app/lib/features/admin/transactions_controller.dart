import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_store_provider.dart';
import '../../core/supabase.dart';
import '../../shared/models/payment_txn.dart';
import '../../shared/models/platform_account.dart';

/// All payments for the admin ledger — QRIS + manual — newest first.
final transactionsProvider = FutureProvider<List<PaymentTxn>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return ref.watch(demoStoreProvider).transactions;
  }
  final rows = await client
      .from('payments')
      .select(
          'id, provider, method, amount, status, reference, created_at, '
          'registrations(user_id, competition_id, competitions(title))')
      .order('created_at', ascending: false);

  final list = rows as List;
  final userIds = <String>{
    for (final r in list)
      if ((r as Map)['registrations']?['user_id'] != null)
        r['registrations']['user_id'] as String
  }.toList();
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
    final m = r as Map<String, dynamic>;
    final reg = m['registrations'] as Map<String, dynamic>?;
    final comp = reg?['competitions'] as Map<String, dynamic>?;
    final userId = (reg?['user_id'] ?? '') as String;
    return PaymentTxn(
      id: m['id'] as String,
      userId: userId,
      userName: names[userId] ?? 'Player',
      competitionId: (reg?['competition_id'] ?? '') as String,
      competitionTitle: (comp?['title'] ?? 'Competition') as String,
      amount: (m['amount'] ?? 0) as int,
      provider: (m['provider'] ?? 'qris') as String,
      method: m['method'] == null
          ? null
          : PayMethod.fromString(m['method'] as String?),
      status: PaymentStatus.fromString(m['status'] as String?),
      reference: m['reference'] as String?,
      createdAt: m['created_at'] == null
          ? null
          : DateTime.tryParse(m['created_at'] as String),
    );
  }).toList();
});

final transactionsServiceProvider =
    Provider<TransactionsService>((ref) => TransactionsService(ref));

class TransactionsService {
  TransactionsService(this._ref);
  final Ref _ref;

  Future<void> confirm(String paymentId) => _act(paymentId, 'confirm');
  Future<void> reject(String paymentId) => _act(paymentId, 'reject');

  Future<void> _act(String paymentId, String action) async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) {
      final store = _ref.read(demoStoreProvider);
      if (action == 'reject') {
        store.rejectManualPayment(paymentId);
      } else {
        store.confirmManualPayment(paymentId);
      }
      _ref.invalidate(transactionsProvider);
      return;
    }
    await client.functions.invoke('admin-confirm-payment',
        body: {'payment_id': paymentId, 'action': action});
    _ref.invalidate(transactionsProvider);
  }
}
