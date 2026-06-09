class ClientGroupAdvanceRecovery {
  final String id;
  final String reference;
  final double amount;
  final DateTime? recoveredAt;
  final ClientGroupAdvanceRecoveryContribution? contribution;

  const ClientGroupAdvanceRecovery({
    required this.id,
    required this.reference,
    required this.amount,
    required this.recoveredAt,
    required this.contribution,
  });

  factory ClientGroupAdvanceRecovery.fromMap(Map<dynamic, dynamic> map) {
    return ClientGroupAdvanceRecovery(
      id: '${map['id'] ?? ''}',
      reference: '${map['reference'] ?? ''}',
      amount: _toDouble(map['amount']),
      recoveredAt: _toDate(map['recoveredAt']),
      contribution: map['contribution'] is Map
          ? ClientGroupAdvanceRecoveryContribution.fromMap(
              Map<dynamic, dynamic>.from(map['contribution'] as Map),
            )
          : null,
    );
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

class ClientGroupAdvanceRecoveryContribution {
  final String id;
  final int turnNumber;
  final DateTime? dueDate;

  const ClientGroupAdvanceRecoveryContribution({
    required this.id,
    required this.turnNumber,
    required this.dueDate,
  });

  factory ClientGroupAdvanceRecoveryContribution.fromMap(
    Map<dynamic, dynamic> map,
  ) {
    return ClientGroupAdvanceRecoveryContribution(
      id: '${map['id'] ?? ''}',
      turnNumber: int.tryParse('${map['turnNumber'] ?? ''}') ?? 0,
      dueDate: ClientGroupAdvanceRecovery._toDate(map['dueDate']),
    );
  }
}
