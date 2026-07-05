import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_store_provider.dart';
import '../../core/supabase.dart';
import '../../shared/models/platform_account.dart';

/// The platform's manual-transfer receiving accounts (bank / OVO / DANA /
/// GoPay). Read by checkout (where to transfer) and the admin editor. Always
/// returns one entry per [PayMethod], in enum order.
final platformAccountsProvider =
    FutureProvider<List<PlatformAccount>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return ref.watch(demoStoreProvider).platformAccounts;
  }
  final rows = await client.from('platform_payment_accounts').select();
  final byMethod = {
    for (final r in rows as List)
      PayMethod.fromString((r as Map<String, dynamic>)['method'] as String?):
          PlatformAccount.fromMap(r)
  };
  return PayMethod.values
      .map((m) =>
          byMethod[m] ??
          PlatformAccount(
              id: m.name, method: m, accountName: '', accountNumber: ''))
      .toList();
});

/// Only the accounts that an admin has actually filled in and left active —
/// the transfer options a player sees at checkout.
final activePlatformAccountsProvider =
    FutureProvider<List<PlatformAccount>>((ref) async {
  final all = await ref.watch(platformAccountsProvider.future);
  return all.where((a) => a.active && a.isConfigured).toList();
});

final platformAccountsServiceProvider =
    Provider<PlatformAccountsService>((ref) => PlatformAccountsService(ref));

class PlatformAccountsService {
  PlatformAccountsService(this._ref);
  final Ref _ref;

  Future<void> save(PlatformAccount account) async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) {
      _ref.read(demoStoreProvider).savePlatformAccount(account);
      _ref.invalidate(platformAccountsProvider);
      return;
    }
    await client
        .from('platform_payment_accounts')
        .upsert(account.toUpsert(), onConflict: 'method');
    _ref.invalidate(platformAccountsProvider);
  }
}
