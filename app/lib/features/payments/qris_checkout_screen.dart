import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/demo_store_provider.dart';
import '../../core/formatters.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../shared/models/competition.dart';
import '../../shared/widgets/brand.dart';
import '../auth/auth_controller.dart';
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
  bool _paid = false;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _invoice = ref
        .read(qrisServiceProvider)
        .createInvoice(widget.competition);
  }

  /// Confirms the join after (mock) payment: registers the user offline, or
  /// confirms the mock payment via the Edge Function in backend mode.
  Future<void> _confirmJoin(QrisInvoice? inv) async {
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    setState(() => _joining = true);
    try {
      final client = ref.read(supabaseClientProvider);
      if (client == null) {
        ref.read(demoStoreProvider).register(
            widget.competition.id, user.id, user.displayName);
      } else if (widget.competition.entryFee > 0 && inv?.paymentId != null) {
        await client.functions
            .invoke('qris-mock-pay', body: {'payment_id': inv!.paymentId});
      }
      ref.invalidate(competitionsControllerProvider);
      if (mounted) setState(() => _paid = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not join: $e')));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final free = widget.competition.entryFee == 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: FutureBuilder<QrisInvoice>(
        future: _invoice,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
                title: 'Could not start payment', subtitle: '${snap.error}');
          }
          final inv = snap.data!;
          if (_paid) return _Success(competition: widget.competition);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(widget.competition.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              if (free)
                _FreeJoin(busy: _joining, onJoin: () => _confirmJoin(inv))
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
                const Center(
                  child: Text('Scan with any QRIS app — GoPay, OVO, DANA, '
                      'ShopeePay, m-banking',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60)),
                ),
                const SizedBox(height: 20),
                _Breakdown(invoice: inv),
                if (inv.mock) ...[
                  const SizedBox(height: 16),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.science_outlined,
                              color: AppColors.gold, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Mock mode — no real charge. Use the button below '
                              'to simulate a successful QRIS payment.',
                              style: TextStyle(color: Colors.white70),
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
                    label: const Text('Simulate payment success'),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('Waiting for payment…',
                        style: TextStyle(color: Colors.white54)),
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
  const _Breakdown({required this.invoice});
  final QrisInvoice invoice;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row('Entry fee', Format.rupiah(invoice.amount)),
            const Divider(height: 18),
            _row('Platform fee (10%)', '− ${Format.rupiah(invoice.platformFee)}',
                muted: true),
            _row('Organizer receives', Format.rupiah(invoice.organizerNet),
                muted: true),
            const Divider(height: 18),
            _row('You pay', Format.rupiah(invoice.amount), bold: true),
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
  const _FreeJoin({required this.onJoin, this.busy = false});
  final VoidCallback onJoin;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.celebration_outlined,
            size: 56, color: AppColors.success),
        const SizedBox(height: 12),
        const Text('This competition is free to enter.',
            style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: busy ? null : onJoin,
          icon: busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check),
          label: const Text('Confirm my spot'),
        ),
      ],
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.competition});
  final Competition competition;

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
            const Text("You're in!",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              'Registered for ${competition.title}. Check the competition page '
              'for the bracket and technical-meeting link.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to competition'),
            ),
          ],
        ),
      ),
    );
  }
}
