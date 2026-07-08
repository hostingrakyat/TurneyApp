import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../shared/models/platform_account.dart';
import '../../shared/widgets/app_loader.dart';
import '../../shared/widgets/brand.dart';
import '../payments/platform_accounts_controller.dart';

/// Admin screen to set the platform's manual-transfer receiving accounts —
/// bank / OVO / DANA / GoPay. These are shown to players who pay by transfer.
class PaymentAccountsScreen extends ConsumerWidget {
  const PaymentAccountsScreen({super.key});

  IconData _icon(PayMethod m) => switch (m) {
        PayMethod.bank => Icons.account_balance,
        _ => Icons.account_balance_wallet,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final accounts = ref.watch(platformAccountsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('pay.accountsTitle'))),
      body: accounts.when(
        loading: () => const AppLoading(),
        error: (e, _) =>
            EmptyState(title: s.t('detail.loadError'), subtitle: '$e'),
        data: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(s.t('pay.accountsSub'),
                style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 12),
            for (final a in list)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(_icon(a.method), color: AppColors.cyan),
                  title: Text(a.method.label,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    a.isConfigured
                        ? [
                            if (a.method == PayMethod.bank && a.bankName != null)
                              a.bankName,
                            a.accountNumber,
                            a.accountName,
                          ].whereType<String>().where((x) => x.isNotEmpty).join(' · ')
                        : s.t('pay.notSet'),
                    style: TextStyle(
                        color: a.isConfigured
                            ? Colors.white70
                            : AppColors.gold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (a.isConfigured && !a.active)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TagPill(s.t('pay.inactive'),
                              color: Colors.white38),
                        ),
                      const Icon(Icons.edit, size: 18),
                    ],
                  ),
                  onTap: () => _edit(context, ref, a),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, PlatformAccount account) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditSheet(account: account),
    );
  }
}

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.account});
  final PlatformAccount account;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final _name = TextEditingController(text: widget.account.accountName);
  late final _number =
      TextEditingController(text: widget.account.accountNumber);
  late final _bank = TextEditingController(text: widget.account.bankName ?? '');
  late final _instructions =
      TextEditingController(text: widget.account.instructions ?? '');
  late bool _active = widget.account.active;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _bank.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    setState(() => _saving = true);
    final updated = widget.account.copyWith(
      accountName: _name.text.trim(),
      accountNumber: _number.text.trim(),
      bankName: widget.account.method == PayMethod.bank
          ? _bank.text.trim()
          : null,
      instructions:
          _instructions.text.trim().isEmpty ? null : _instructions.text.trim(),
      active: _active,
    );
    try {
      await ref.read(platformAccountsServiceProvider).save(updated);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.t('pay.saved'))));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final isBank = widget.account.method == PayMethod.bank;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.t('pay.editAccount').replaceFirst('{x}', widget.account.method.label),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          if (isBank) ...[
            TextField(
              controller: _bank,
              decoration: InputDecoration(
                labelText: s.t('pay.bankName'),
                prefixIcon: const Icon(Icons.account_balance),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _number,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: s.t('pay.accountNumber'),
              prefixIcon: const Icon(Icons.numbers),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: s.t('pay.accountName'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instructions,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: s.t('pay.instructions'),
              alignLabelWithHint: true,
              prefixIcon: const Icon(Icons.info_outline),
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: Text(s.t('pay.active')),
            subtitle: Text(s.t('pay.activeSub')),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(s.t('common.save')),
          ),
        ],
      ),
    );
  }
}
