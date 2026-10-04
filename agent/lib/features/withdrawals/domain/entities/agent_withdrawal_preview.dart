class AgentWithdrawalPreview {
  final String clientId;
  final String clientDisplayName;
  final String clientPhoneNumber;
  final double availableBalance;
  final double amount;

  const AgentWithdrawalPreview({
    required this.clientId,
    required this.clientDisplayName,
    required this.clientPhoneNumber,
    required this.availableBalance,
    required this.amount,
  });

  factory AgentWithdrawalPreview.fromMap(Map<dynamic, dynamic> map) {
    return AgentWithdrawalPreview(
      clientId: map['clientId']?.toString() ?? '',
      clientDisplayName: map['clientDisplayName']?.toString() ?? '',
      clientPhoneNumber: map['clientPhoneNumber']?.toString() ?? '',
      availableBalance: _toDouble(map['availableBalance']),
      amount: _toDouble(map['amount']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
