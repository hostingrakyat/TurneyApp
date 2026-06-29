import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../core/supabase.dart';
import '../../shared/models/competition.dart';

/// A QRIS invoice ready to be paid (real or mock).
class QrisInvoice {
  const QrisInvoice({
    required this.invoiceId,
    required this.qrisString,
    required this.amount,
    required this.platformFee,
    this.mock = false,
    this.paymentId,
  });

  final String invoiceId;
  final String qrisString;
  final int amount;
  final int platformFee;
  final bool mock;

  /// Supabase `payments.id` — used to confirm the mock payment. Null offline.
  final String? paymentId;

  int get organizerNet => amount - platformFee;
}

final qrisServiceProvider = Provider<QrisService>((ref) {
  return QrisService(ref);
});

class QrisService {
  QrisService(this._ref);
  final Ref _ref;

  /// Creates a dynamic QRIS invoice for a registration. When a backend is
  /// configured this calls the `qris-create-invoice` Edge Function; otherwise
  /// it returns a mock invoice so the flow is fully explorable offline.
  Future<QrisInvoice> createInvoice(Competition competition) async {
    final amount = competition.entryFee;
    final fee = (amount * Env.platformFeeRate).round();
    final client = _ref.read(supabaseClientProvider);

    if (client == null) {
      return _mockInvoice(amount, fee);
    }

    final res = await client.functions.invoke(
      'qris-create-invoice',
      body: {
        'competition_id': competition.id,
        'amount': amount,
      },
    );
    final data = res.data as Map<String, dynamic>;
    if (data['free'] == true) {
      // Free entry: the function already registered + marked paid.
      return const QrisInvoice(
          invoiceId: '', qrisString: '', amount: 0, platformFee: 0);
    }
    return QrisInvoice(
      invoiceId: data['invoice_id'] as String,
      qrisString: data['qris_string'] as String,
      amount: amount,
      platformFee: (data['platform_fee'] as num?)?.toInt() ?? fee,
      mock: (data['mock'] as bool?) ?? false,
      paymentId: data['payment_id'] as String?,
    );
  }

  QrisInvoice _mockInvoice(int amount, int fee) {
    final id = 'MOCK-${DateTime.now().millisecondsSinceEpoch}';
    // A representative (non-real) EMVCo-style QRIS payload for display only.
    final rand = Random().nextInt(999999).toString().padLeft(6, '0');
    final qris =
        '00020101021226670016COM.TURNEYAPP.WWW01189360091234567890210$rand'
        '5204599953033605802ID5909TurneyApp6007Jakarta6304MOCK';
    return QrisInvoice(
      invoiceId: id,
      qrisString: qris,
      amount: amount,
      platformFee: fee,
      mock: true,
    );
  }
}
