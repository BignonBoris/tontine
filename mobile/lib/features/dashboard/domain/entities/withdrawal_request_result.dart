class WithdrawalRequestResult {
  final String id;
  final String reference;
  final double amount;
  final String status;
  final String confirmationCode;
  final DateTime confirmationCodeExpiresAt;
  final DateTime requestedAt;

  const WithdrawalRequestResult({
    required this.id,
    required this.reference,
    required this.amount,
    required this.status,
    required this.confirmationCode,
    required this.confirmationCodeExpiresAt,
    required this.requestedAt,
  });

  factory WithdrawalRequestResult.fromMap(Map<dynamic, dynamic> map) {
    return WithdrawalRequestResult(
      id: map['id']?.toString() ?? '',
      reference: map['reference']?.toString() ?? '',
      amount: _toDouble(map['amount']),
      status: map['status']?.toString() ?? '',
      confirmationCode: map['confirmationCode']?.toString() ?? '',
      confirmationCodeExpiresAt: _toDateTime(map['confirmationCodeExpiresAt']),
      requestedAt: _toDateTime(map['requestedAt']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse('$value') ?? DateTime.now();
  }
}
