import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../shared/models/payout_account.dart';
import '../../shared/widgets/brand.dart';
import 'payout_controller.dart';

class PayoutScreen extends ConsumerWidget {
  const PayoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(payoutControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reward payouts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(title: 'Could not load', subtitle: '$e'),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const Text(
              'Where should we send your winnings? Add a bank account or '
              'e-wallet (DANA, OVO, GoPay, ShopeePay). This is optional — you '
              'can skip it now and add one before your first payout.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 16),
            if (list.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          size: 40, color: Colors.white38),
                      const SizedBox(height: 10),
                      const Text("No payout account yet",
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text(
                        "That's fine — you don't have one on file. "
                        'Add it any time before claiming a reward.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...list.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AccountTile(account: a),
                  )),
          ],
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AddPayoutSheet(),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account});
  final PayoutAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: account.type.isEwallet
              ? AppColors.cyan.withValues(alpha: 0.2)
              : AppColors.violet.withValues(alpha: 0.2),
          child: Icon(
            account.type.isEwallet
                ? Icons.account_balance_wallet
                : Icons.account_balance,
            color: account.type.isEwallet ? AppColors.cyan : AppColors.violet,
          ),
        ),
        title: Row(
          children: [
            Text(account.type.label,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (account.isDefault) ...[
              const SizedBox(width: 8),
              const TagPill('Default', color: AppColors.success),
            ],
          ],
        ),
        subtitle: Text('${account.accountName} · ${account.accountNumber}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () =>
              ref.read(payoutControllerProvider.notifier).remove(account.id),
        ),
      ),
    );
  }
}

class _AddPayoutSheet extends ConsumerStatefulWidget {
  const _AddPayoutSheet();

  @override
  ConsumerState<_AddPayoutSheet> createState() => _AddPayoutSheetState();
}

class _AddPayoutSheetState extends ConsumerState<_AddPayoutSheet> {
  PayoutType _type = PayoutType.dana;
  final _name = TextEditingController();
  final _number = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await ref.read(payoutControllerProvider.notifier).add(
          type: _type,
          accountName: _name.text,
          accountNumber: _number.text,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add payout account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: PayoutType.values
                  .map((t) => ChoiceChip(
                        label: Text(t.label),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Account holder name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _number,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _type == PayoutType.bank
                    ? 'Account number'
                    : 'Phone / wallet number',
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 4) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
