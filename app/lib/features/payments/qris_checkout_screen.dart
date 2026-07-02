import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/demo_store_provider.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../shared/models/competition.dart';
import '../../shared/widgets/brand.dart';
import '../auth/auth_controller.dart';
import '../auth/payout_controller.dart';
import '../competitions/competitions_controller.dart';
import 'qris_service.dart';

class QrisCheckoutScreen extends ConsumerStatefulWidget {
  const QrisCheckoutScreen({super.key, required this.competition});

  final Competition competition;

  @override
  ConsumerState<QrisCheckoutScreen> createState() =>
      _QrisCheckoutScreenState();
}

class _QrisCheckoutScreenState extends ConsumerState<QrisCheckoutScreen> {
  late Future<QrisInvoice> _invoice;
  final _phone = TextEditingController();
  bool _detailsDone = false;
  bool _paid = false;
  bool _joining = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _invoice = ref
        .read(qrisServiceProvider)
        .createInvoice(widget.competition);
    _phone.text = ref.read(authControllerProvider)?.phone ?? '';
    // For a real (non-mock) QRIS, poll until the qris.id callback settles it.
    _invoice.then((inv) {
      if (mounted && !inv.mock && inv.paymentId != null) _startPolling(inv);
    }).catchError((_) {});
  }

  void _startPolling(QrisInvoice inv) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _paid) return;
      final paid = await ref.read(qrisServiceProvider).isPaid(inv.paymentId!);
      if (paid && mounted) {
        _poll?.cancel();
        await _confirmJoin(inv, mock: false);
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _phone.dispose();
    super.dispose();
  }

  /// Saves the player's phone (so the organizer can add them to the group),
  /// then advances to payment.
  Future<void> _continueDetails() async {
    final s = ref.read(stringsProvider);
    final phone = _phone.text.trim();
    if (phone.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('checkout.phoneInvalid'))),
      );
      return;
    }
    final user = ref.read(authControllerProvider);
    final client = ref.read(supabaseClientProvider);
    if (client != null && user != null) {
      await client.from('profiles').update({'phone': phone}).eq('id', user.id);
    }
    if (mounted) setState(() => _detailsDone = true);
  }

  /// Manual "I've paid — check now" for the live path.
  Future<void> _checkNow(QrisInvoice inv) async {
    final s = ref.read(stringsProvider);
    if (inv.paymentId == null) return;
    final paid = await ref.read(qrisServiceProvider).isPaid(inv.paymentId!);
    if (paid) {
      await _confirmJoin(inv, mock: false);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('checkout.notPaidYet'))));
    }
  }

  /// Confirms the join. For [mock] payments (or offline) this simulates the
  /// settlement; for a real QRIS the payment is already settled by the callback
  /// and we just record the phone and show success.
  Future<void> _confirmJoin(QrisInvoice? inv, {bool mock = true}) async {
    final s = ref.read(stringsProvider);
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    setState(() => _joining = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final phone = _phone.text.trim();
      if (client == null) {
        ref.read(demoStoreProvider).register(
            widget.competition.id, user.id, user.displayName, phone);
      } else {
        if (mock &&
            widget.competition.entryFee > 0 &&
            inv?.paymentId != null) {
          await client.functions
              .invoke('qris-mock-pay', body: {'payment_id': inv!.paymentId});
        }
        await client.from('registrations').update({'phone': phone}).eq(
            'competition_id', widget.competition.id).eq('user_id', user.id);
      }
      ref.invalidate(competitionsControllerProvider);
      ref.invalidate(isRegisteredProvider(widget.competition.id));
      if (mounted) setState(() => _paid = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(s.t('checkout.joinError').replaceFirst('{x}', '$e'))));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Widget _buildDetails(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final accounts = ref.watch(payoutControllerProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(widget.competition.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Text(s.t('checkout.yourDetails'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
          ],
          decoration: InputDecoration(
            labelText: s.t('checkout.phone'),
            helperText: s.t('checkout.phoneHelper'),
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 20),
        Text(s.t('checkout.payoutAccount'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          s.t('checkout.payoutSub'),
          style: const TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 10),
        accounts.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (list) => Column(
            children: [
              for (final a in list)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      a.type.isEwallet
                          ? Icons.account_balance_wallet
                          : Icons.account_balance,
                      color: AppColors.cyan,
                    ),
                    title: Text(a.type.label),
                    subtitle: Text('${a.accountName} · ${a.accountNumber}'),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => context.push('/payout'),
                icon: const Icon(Icons.add),
                label: Text(list.isEmpty
                    ? s.t('checkout.addAccount')
                    : s.t('checkout.manageAccounts')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _continueDetails,
          icon: const Icon(Icons.arrow_forward),
          label: Text(widget.competition.entryFee == 0
              ? s.t('checkout.continueJoin')
              : s.t('checkout.continuePay')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final free = widget.competition.entryFee == 0;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('checkout.title'))),
      body: !_detailsDone && !_paid
          ? _buildDetails(context)
          : FutureBuilder<QrisInvoice>(
        future: _invoice,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
                title: s.t('checkout.startError'), subtitle: '${snap.error}');
          }
          final inv = snap.data!;
          if (_paid) return _Success(competition: widget.competition, strings: s);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(widget.competition.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              if (free)
                _FreeJoin(
                    busy: _joining,
                    strings: s,
                    onJoin: () => _confirmJoin(inv))
              else ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: QrImageView(
                      data: inv.qrisString,
                      version: QrVersions.auto,
                      size: 220,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(s.t('checkout.scanHint'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60)),
                ),
                const SizedBox(height: 20),
                _Breakdown(invoice: inv, strings: s),
                if (inv.mock) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.science_outlined,
                              color: AppColors.gold, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.t('checkout.mockNote'),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _joining ? null : () => _confirmJoin(inv),
                    icon: _joining
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline),
                    label: Text(s.t('checkout.simulate')),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                            height: 16,
                            width: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 10),
                        Text(s.t('checkout.waiting'),
                            style: const TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _joining ? null : () => _checkNow(inv),
                    icon: const Icon(Icons.refresh),
                    label: Text(s.t('checkout.checkNow')),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.invoice, required this.strings});
  final QrisInvoice invoice;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(strings.t('checkout.entryFee'), Format.rupiah(invoice.amount)),
            const Divider(height: 18),
            _row(strings.t('checkout.platformFee'),
                '− ${Format.rupiah(invoice.platformFee)}',
                muted: true),
            _row(strings.t('checkout.organizerGets'),
                Format.rupiah(invoice.organizerNet),
                muted: true),
            const Divider(height: 18),
            _row(strings.t('checkout.youPay'), Format.rupiah(invoice.amount),
                bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value,
      {bool bold = false, bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: muted ? Colors.white54 : Colors.white)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: muted ? Colors.white54 : Colors.white)),
        ],
      ),
    );
  }
}

class _FreeJoin extends StatelessWidget {
  const _FreeJoin(
      {required this.onJoin, required this.strings, this.busy = false});
  final VoidCallback onJoin;
  final AppStrings strings;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.celebration_outlined,
            size: 56, color: AppColors.success),
        const SizedBox(height: 12),
        Text(strings.t('checkout.freeEntry'),
            style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: busy ? null : onJoin,
          icon: busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check),
          label: Text(strings.t('checkout.confirmSpot')),
        ),
      ],
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.competition, required this.strings});
  final Competition competition;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, color: AppColors.success, size: 72),
            const SizedBox(height: 16),
            Text(strings.t('checkout.successTitle'),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              strings
                  .t('checkout.successBody')
                  .replaceFirst('{x}', competition.title),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings.t('checkout.backToComp')),
            ),
          ],
        ),
      ),
    );
  }
}
