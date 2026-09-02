class WithdrawalRequestResult {
  final String id;
  final String reference;
  final double amount;
  final String status;
  final String channel;
  final String? confirmationCode;
  final DateTime? confirmationCodeExpiresAt;
  final DateTime requestedAt;
  final bool requiresConfirmationCode;
  final bool requiresAdminReview;

  const WithdrawalRequestResult({
    required this.id,
    required this.reference,
    required this.amount,
    required this.status,
    required this.channel,
    this.confirmationCode,
    this.confirmationCodeExpiresAt,
    required this.requestedAt,
    this.requiresConfirmationCode = false,
    this.requiresAdminReview = false,
  });

  factory WithdrawalRequestResult.fromMap(Map<dynamic, dynamic> map) {
    return WithdrawalRequestResult(
      id: map['id']?.toString() ?? '',
      reference: map['reference']?.toString() ?? '',
      amount: _toDouble(map['amount']),
      status: map['status']?.toString() ?? '',
      channel: map['channel']?.toString() ?? 'agent_cash',
      confirmationCode: map['confirmationCode']?.toString(),
      confirmationCodeExpiresAt: map['confirmationCodeExpiresAt'] == null
          ? null
          : _toDateTime(map['confirmationCodeExpiresAt']),
      requestedAt: _toDateTime(map['requestedAt']),
      requiresConfirmationCode:
          map['requiresConfirmationCode'] as bool? ?? false,
      requiresAdminReview: map['requiresAdminReview'] as bool? ?? false,
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
