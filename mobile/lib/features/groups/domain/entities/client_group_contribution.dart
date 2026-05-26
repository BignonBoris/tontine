class ClientGroupContribution {
  final String id;
  final int turnNumber;
  final DateTime? dueDate;
  final double amount;
  final String status;
  final String? paymentSource;
  final DateTime? paidAt;
  final ClientGroupContributionParty? beneficiary;

  const ClientGroupContribution({
    required this.id,
    required this.turnNumber,
    required this.dueDate,
    required this.amount,
    required this.status,
    required this.paymentSource,
    required this.paidAt,
    required this.beneficiary,
  });

  bool get isPaid => status == 'paid';
  bool get isMissed => status == 'missed';

  factory ClientGroupContribution.fromMap(Map<dynamic, dynamic> map) {
    return ClientGroupContribution(
      id: '${map['id'] ?? ''}',
      turnNumber: _toInt(map['turnNumber']),
      dueDate: _toDate(map['dueDate']),
      amount: _toDouble(map['amount']),
      status: '${map['status'] ?? 'pending'}',
      paymentSource: map['paymentSource']?.toString(),
      paidAt: _toDate(map['paidAt']),
      beneficiary: map['beneficiary'] is Map
          ? ClientGroupContributionParty.fromMap(
              Map<dynamic, dynamic>.from(map['beneficiary'] as Map),
            )
          : null,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}

class ClientGroupContributionParty {
  final String id;
  final String displayName;
  final String phoneNumber;

  const ClientGroupContributionParty({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
  });

  factory ClientGroupContributionParty.fromMap(Map<dynamic, dynamic> map) {
    return ClientGroupContributionParty(
      id: '${map['id'] ?? ''}',
      displayName: '${map['displayName'] ?? ''}',
      phoneNumber: '${map['phoneNumber'] ?? ''}',
    );
  }
}
