/// A platform-owned receiving account players transfer their entry fee to when
/// they pay manually (bank transfer / e-wallet). Set by an admin. The QRIS path
/// stays automatic; this covers manual bank / OVO / DANA / GoPay transfers that
/// an admin confirms by hand.
enum PayMethod {
  bank,
  ovo,
  dana,
  gopay;

  static PayMethod fromString(String? v) => PayMethod.values.firstWhere(
        (e) => e.name == v,
        orElse: () => PayMethod.bank,
      );

  String get label => switch (this) {
        PayMethod.bank => 'Bank transfer',
        PayMethod.ovo => 'OVO',
        PayMethod.dana => 'DANA',
        PayMethod.gopay => 'GoPay',
      };

  bool get isEwallet => this != PayMethod.bank;
}

class PlatformAccount {
  const PlatformAccount({
    required this.id,
    required this.method,
    required this.accountName,
    required this.accountNumber,
    this.bankName,
    this.instructions,
    this.active = true,
  });

  final String id;
  final PayMethod method;

  /// Registered holder name on the account.
  final String accountName;

  /// Account / phone number the player transfers to.
  final String accountNumber;

  /// Bank name — only meaningful for [PayMethod.bank].
  final String? bankName;

  /// Optional free-text instructions shown at checkout.
  final String? instructions;
  final bool active;

  /// True once the account has a usable number filled in.
  bool get isConfigured => accountNumber.trim().isNotEmpty;

  PlatformAccount copyWith({
    String? accountName,
    String? accountNumber,
    String? bankName,
    String? instructions,
    bool? active,
  }) =>
      PlatformAccount(
        id: id,
        method: method,
        accountName: accountName ?? this.accountName,
        accountNumber: accountNumber ?? this.accountNumber,
        bankName: bankName ?? this.bankName,
        instructions: instructions ?? this.instructions,
        active: active ?? this.active,
      );

  factory PlatformAccount.fromMap(Map<String, dynamic> m) => PlatformAccount(
        id: m['id'] as String,
        method: PayMethod.fromString(m['method'] as String?),
        accountName: (m['account_name'] ?? '') as String,
        accountNumber: (m['account_number'] ?? '') as String,
        bankName: m['bank_name'] as String?,
        instructions: m['instructions'] as String?,
        active: (m['is_active'] ?? true) as bool,
      );

  /// Upsert payload keyed by [method] (unique) — the backend row id is a
  /// server-generated uuid, so it is intentionally omitted here.
  Map<String, dynamic> toUpsert() => {
        'method': method.name,
        'account_name': accountName,
        'account_number': accountNumber,
        'bank_name': bankName,
        'instructions': instructions,
        'is_active': active,
        'updated_at': DateTime.now().toIso8601String(),
      };
}
