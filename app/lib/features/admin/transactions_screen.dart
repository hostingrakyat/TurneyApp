import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../shared/models/payment_txn.dart';
import '../../shared/widgets/brand.dart';
import 'transactions_controller.dart';

/// Admin ledger of every payment. Pending manual transfers surface a
/// Confirm / Reject action; confirming runs the same fee split as QRIS.
class AdminTransactionsScreen extends ConsumerWidget {
  const AdminTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final txns = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('txn.title'))),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(transactionsProvider),
        child: txns.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              EmptyState(title: s.t('detail.loadError'), subtitle: '$e'),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  title: s.t('txn.empty'),
                  subtitle: s.t('txn.emptySub'),
                  icon: Icons.receipt_long_outlined,
                ),
              ]);
            }
            final pending = list.where((t) => t.isPendingManual).toList();
            final rest = list.where((t) => !t.isPendingManual).toList();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pending.isNotEmpty) ...[
                  _SectionLabel(
                      '${s.t('txn.needsReview')} · ${pending.length}'),
                  for (final t in pending) _TxnCard(txn: t),
                  const SizedBox(height: 16),
                ],
                if (rest.isNotEmpty) ...[
                  _SectionLabel(s.t('txn.history')),
                  for (final t in rest) _TxnCard(txn: t),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );
}

Color _statusColor(PaymentStatus s) => switch (s) {
      PaymentStatus.paid => AppColors.success,
      PaymentStatus.pending => AppColors.gold,
      PaymentStatus.failed || PaymentStatus.expired => AppColors.danger,
    };

String _statusLabel(PaymentStatus st, AppStrings s) => switch (st) {
      PaymentStatus.paid => s.t('txn.statusPaid'),
      PaymentStatus.pending => s.t('txn.statusPending'),
      PaymentStatus.failed => s.t('txn.statusRejected'),
      PaymentStatus.expired => s.t('txn.statusExpired'),
    };

class _TxnCard extends ConsumerStatefulWidget {
  const _TxnCard({required this.txn});
  final PaymentTxn txn;
  @override
  ConsumerState<_TxnCard> createState() => _TxnCardState();
}

class _TxnCardState extends ConsumerState<_TxnCard> {
  bool _busy = false;

  Future<void> _act(bool confirm) async {
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    try {
      final svc = ref.read(transactionsServiceProvider);
      if (confirm) {
        await svc.confirm(widget.txn.id);
      } else {
        await svc.reject(widget.txn.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                confirm ? s.t('txn.confirmed') : s.t('txn.rejected'))));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final t = widget.txn;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${t.userName} · ${Format.rupiah(t.amount)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                TagPill(_statusLabel(t.status, s), color: _statusColor(t.status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(t.competitionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                    t.isManual
                        ? Icons.swap_horiz
                        : Icons.qr_code_2,
                    size: 15,
                    color: Colors.white38),
                const SizedBox(width: 6),
                Text(t.channelLabel,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                if (t.reference != null && t.reference!.isNotEmpty) ...[
                  const Text('  ·  ',
                      style: TextStyle(color: Colors.white24, fontSize: 12)),
                  Flexible(
                    child: Text(t.reference!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ),
                ],
              ],
            ),
            if (t.isPendingManual) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _act(false),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger),
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(s.t('txn.reject')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _act(true),
                      icon: _busy
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check, size: 18),
                      label: Text(s.t('txn.confirm')),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
