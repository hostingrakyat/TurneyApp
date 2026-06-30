enum PayoutStatus {
  owed,
  paid;

  static PayoutStatus fromString(String? v) =>
      v == 'paid' ? PayoutStatus.paid : PayoutStatus.owed;

  String get label => this == PayoutStatus.paid ? 'Paid' : 'Owed';
}

/// Reward owed to (or paid to) a user for a competition.
class Payout {
  const Payout({
    required this.id,
    required this.userId,
    required this.userName,
    required this.competitionId,
    required this.competitionTitle,
    required this.amount,
    this.status = PayoutStatus.owed,
  });

  final String id;
  final String userId;
  final String userName;
  final String competitionId;
  final String competitionTitle;
  final int amount;
  final PayoutStatus status;

  factory Payout.fromMap(Map<String, dynamic> m) => Payout(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        userName: (m['user_name'] ?? 'Player') as String,
        competitionId: (m['competition_id'] ?? '') as String,
        competitionTitle: (m['competition_title'] ?? 'Competition') as String,
        amount: (m['amount'] ?? 0) as int,
        status: PayoutStatus.fromString(m['status'] as String?),
      );
}
