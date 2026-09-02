class WithdrawalSummary {
  final String id;
  final String reference;
  final double amount;
  final String status;
  final String channel;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final String? approvedByAdminUsername;
  final DateTime? paidAt;
  final String? paidByAdminUsername;
  final DateTime? cancelledAt;
  final DateTime? rejectedAt;
  final String? cancellationReason;
  final String? rejectionReason;
  final String? paymentReference;
  final String? paymentProofImageUrl;
  final DateTime? paymentProofUploadedAt;
  final DateTime? confirmationCodeExpiresAt;
  final bool isConfirmationCodeExpired;

  const WithdrawalSummary({
    required this.id,
    required this.reference,
    required this.amount,
    required this.status,
    required this.channel,
    required this.requestedAt,
    this.approvedAt,
    this.approvedByAdminUsername,
    this.paidAt,
    this.paidByAdminUsername,
    this.cancelledAt,
    this.rejectedAt,
    this.cancellationReason,
    this.rejectionReason,
    this.paymentReference,
    this.paymentProofImageUrl,
    this.paymentProofUploadedAt,
    this.confirmationCodeExpiresAt,
    this.isConfirmationCodeExpired = false,
  });

  factory WithdrawalSummary.fromMap(Map<dynamic, dynamic> map) {
    return WithdrawalSummary(
      id: map['id']?.toString() ?? '',
      reference: map['reference']?.toString() ?? '',
      amount: _toDouble(map['amount']),
      status: map['status']?.toString() ?? '',
      channel: map['channel']?.toString() ?? 'agent_cash',
      requestedAt: _toDateTime(map['requestedAt']),
      approvedAt: map['approvedAt'] == null ? null : _toDateTime(map['approvedAt']),
      approvedByAdminUsername: map['approvedByAdminUsername']?.toString(),
      paidAt: map['paidAt'] == null ? null : _toDateTime(map['paidAt']),
      paidByAdminUsername: map['paidByAdminUsername']?.toString(),
      cancelledAt: map['cancelledAt'] == null
          ? null
          : _toDateTime(map['cancelledAt']),
      rejectedAt: map['rejectedAt'] == null ? null : _toDateTime(map['rejectedAt']),
      cancellationReason: map['cancellationReason']?.toString(),
      rejectionReason: map['rejectionReason']?.toString(),
      paymentReference: map['paymentReference']?.toString(),
      paymentProofImageUrl: map['paymentProofImageUrl']?.toString(),
      paymentProofUploadedAt: map['paymentProofUploadedAt'] == null
          ? null
          : _toDateTime(map['paymentProofUploadedAt']),
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
      'channel': channel,
      'requestedAt': requestedAt.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'approvedByAdminUsername': approvedByAdminUsername,
      'paidAt': paidAt?.toIso8601String(),
      'paidByAdminUsername': paidByAdminUsername,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'rejectedAt': rejectedAt?.toIso8601String(),
      'cancellationReason': cancellationReason,
      'rejectionReason': rejectionReason,
      'paymentReference': paymentReference,
      'paymentProofImageUrl': paymentProofImageUrl,
      'paymentProofUploadedAt': paymentProofUploadedAt?.toIso8601String(),
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
