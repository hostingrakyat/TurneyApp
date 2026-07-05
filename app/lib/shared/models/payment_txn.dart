import 'platform_account.dart';

/// Lifecycle of a payment row.
enum PaymentStatus {
  pending,
  paid,
  expired,
  failed;

  static PaymentStatus fromString(String? v) => switch (v) {
        'paid' => PaymentStatus.paid,
        'expired' => PaymentStatus.expired,
        'failed' => PaymentStatus.failed,
        _ => PaymentStatus.pending,
      };

  String get label => switch (this) {
        PaymentStatus.pending => 'Pending',
        PaymentStatus.paid => 'Paid',
        PaymentStatus.expired => 'Expired',
        PaymentStatus.failed => 'Rejected',
      };
}

/// A single payment for the admin transactions ledger. Wraps the `payments`
/// row joined with its registration → competition and the payer's name.
class PaymentTxn {
  const PaymentTxn({
    required this.id,
    required this.userId,
    required this.userName,
    required this.competitionId,
    required this.competitionTitle,
    required this.amount,
    required this.provider,
    required this.status,
    this.method,
    this.reference,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String competitionId;
  final String competitionTitle;
  final int amount;

  /// 'qris' | 'manual' | 'free'.
  final String provider;

  /// For manual transfers: which channel the player used.
  final PayMethod? method;
  final PaymentStatus status;

  /// Sender name / note the player entered for a manual transfer.
  final String? reference;
  final DateTime? createdAt;

  bool get isManual => provider == 'manual';
  bool get isPendingManual => isManual && status == PaymentStatus.pending;

  /// Human channel label: the manual method, or the provider name.
  String get channelLabel => method?.label ?? (provider == 'qris' ? 'QRIS' : provider);

  PaymentTxn copyWith({PaymentStatus? status}) => PaymentTxn(
        id: id,
        userId: userId,
        userName: userName,
        competitionId: competitionId,
        competitionTitle: competitionTitle,
        amount: amount,
        provider: provider,
        method: method,
        status: status ?? this.status,
        reference: reference,
        createdAt: createdAt,
      );
}
