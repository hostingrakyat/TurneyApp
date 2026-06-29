/// Where a user receives competition rewards. Optional — a user may skip this
/// during onboarding and add it later.
enum PayoutType {
  bank,
  dana,
  ovo,
  gopay,
  shopeepay;

  static PayoutType fromString(String? v) => PayoutType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => PayoutType.bank,
      );

  String get label => switch (this) {
        PayoutType.bank => 'Bank account',
        PayoutType.dana => 'DANA',
        PayoutType.ovo => 'OVO',
        PayoutType.gopay => 'GoPay',
        PayoutType.shopeepay => 'ShopeePay',
      };

  bool get isEwallet => this != PayoutType.bank;
}

class PayoutAccount {
  const PayoutAccount({
    required this.id,
    required this.type,
    required this.accountName,
    required this.accountNumber,
    this.isDefault = false,
  });

  final String id;
  final PayoutType type;
  final String accountName;
  final String accountNumber;
  final bool isDefault;

  factory PayoutAccount.fromMap(Map<String, dynamic> m) => PayoutAccount(
        id: m['id'] as String,
        type: PayoutType.fromString(m['type'] as String?),
        accountName: (m['account_name'] ?? '') as String,
        accountNumber: (m['account_number'] ?? '') as String,
        isDefault: (m['is_default'] ?? false) as bool,
      );

  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId,
        'type': type.name,
        'account_name': accountName,
        'account_number': accountNumber,
        'is_default': isDefault,
      };
}
