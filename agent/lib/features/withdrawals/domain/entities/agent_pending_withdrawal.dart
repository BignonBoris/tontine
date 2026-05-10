class AgentPendingWithdrawal {
  final String id;
  final String reference;
  final double amount;
  final String status;
  final DateTime requestedAt;
  final DateTime? confirmationCodeExpiresAt;
  final bool isConfirmationCodeExpired;
  final String? clientDisplayName;
  final String? clientPhoneNumber;

  const AgentPendingWithdrawal({
    required this.id,
    required this.reference,
    required this.amount,
    required this.status,
    required this.requestedAt,
    this.confirmationCodeExpiresAt,
    this.isConfirmationCodeExpired = false,
    this.clientDisplayName,
    this.clientPhoneNumber,
  });

  factory AgentPendingWithdrawal.fromMap(Map<dynamic, dynamic> map) {
    final client =
        map['client'] is Map ? Map<dynamic, dynamic>.from(map['client']) : null;

    return AgentPendingWithdrawal(
      id: map['id']?.toString() ?? '',
      reference: map['reference']?.toString() ?? '',
      amount: _toDouble(map['amount']),
      status: map['status']?.toString() ?? '',
      requestedAt: _toDateTime(map['requestedAt']),
      confirmationCodeExpiresAt: map['confirmationCodeExpiresAt'] == null
          ? null
          : _toDateTime(map['confirmationCodeExpiresAt']),
      isConfirmationCodeExpired: map['isConfirmationCodeExpired'] as bool? ?? false,
      clientDisplayName: client?['displayName']?.toString(),
      clientPhoneNumber: client?['phoneNumber']?.toString(),
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
