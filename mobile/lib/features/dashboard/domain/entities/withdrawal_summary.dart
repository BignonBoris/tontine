class WithdrawalSummary {
  final String id;
  final String reference;
  final double amount;
  final String status;
  final DateTime requestedAt;
  final DateTime? paidAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime? confirmationCodeExpiresAt;
  final bool isConfirmationCodeExpired;

  const WithdrawalSummary({
    required this.id,
    required this.reference,
    required this.amount,
    required this.status,
    required this.requestedAt,
    this.paidAt,
    this.cancelledAt,
    this.cancellationReason,
    this.confirmationCodeExpiresAt,
    this.isConfirmationCodeExpired = false,
  });

  factory WithdrawalSummary.fromMap(Map<dynamic, dynamic> map) {
    return WithdrawalSummary(
      id: map['id']?.toString() ?? '',
      reference: map['reference']?.toString() ?? '',
      amount: _toDouble(map['amount']),
      status: map['status']?.toString() ?? '',
      requestedAt: _toDateTime(map['requestedAt']),
      paidAt: map['paidAt'] == null ? null : _toDateTime(map['paidAt']),
      cancelledAt: map['cancelledAt'] == null
          ? null
          : _toDateTime(map['cancelledAt']),
      cancellationReason: map['cancellationReason']?.toString(),
      confirmationCodeExpiresAt: map['confirmationCodeExpiresAt'] == null
          ? null
          : _toDateTime(map['confirmationCodeExpiresAt']),
      isConfirmationCodeExpired: map['isConfirmationCodeExpired'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reference': reference,
      'amount': amount,
      'status': status,
      'requestedAt': requestedAt.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancellationReason': cancellationReason,
      'confirmationCodeExpiresAt': confirmationCodeExpiresAt?.toIso8601String(),
      'isConfirmationCodeExpired': isConfirmationCodeExpired,
    };
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
