import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/supabase.dart';
import '../../shared/models/payout_account.dart';
import 'auth_controller.dart';

final payoutControllerProvider =
    AsyncNotifierProvider<PayoutController, List<PayoutAccount>>(
        PayoutController.new);

/// Manages the signed-in user's reward payout accounts (bank / e-wallet).
/// Optional — a user may have none. Works against Supabase or in-memory demo.
class PayoutController extends AsyncNotifier<List<PayoutAccount>> {
  final _uuid = const Uuid();

  @override
  Future<List<PayoutAccount>> build() async {
    final client = ref.watch(supabaseClientProvider);
    final user = ref.watch(authControllerProvider);
    if (client == null || user == null) return const [];
    final rows = await client
        .from('payout_accounts')
        .select()
        .eq('user_id', user.id)
        .order('is_default', ascending: false);
    return (rows as List)
        .map((r) => PayoutAccount.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> add({
    required PayoutType type,
    required String accountName,
    required String accountNumber,
  }) async {
    final client = ref.read(supabaseClientProvider);
    final user = ref.read(authControllerProvider);
    final current = state.value ?? const <PayoutAccount>[];
    final account = PayoutAccount(
      id: _uuid.v4(),
      type: type,
      accountName: accountName.trim(),
      accountNumber: accountNumber.trim(),
      isDefault: current.isEmpty,
    );
    if (client == null || user == null) {
      state = AsyncData([...current, account]);
      return;
    }
    await client.from('payout_accounts').insert(account.toInsert(user.id));
    ref.invalidateSelf();
  }

  Future<void> remove(String id) async {
    final client = ref.read(supabaseClientProvider);
    final current = state.value ?? const <PayoutAccount>[];
    if (client == null) {
      state = AsyncData(current.where((a) => a.id != id).toList());
      return;
    }
    await client.from('payout_accounts').delete().eq('id', id);
    ref.invalidateSelf();
  }
}
