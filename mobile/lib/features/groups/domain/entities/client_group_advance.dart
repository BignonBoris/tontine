class ClientGroupAdvance {
  final String id;
  final double amount;
  final double recoveredAmount;
  final double remainingAmount;
  final String status;
  final DateTime? advancedAt;
  final ClientGroupAdvanceParty? beneficiary;
  final ClientGroupAdvanceContribution? contribution;

  const ClientGroupAdvance({
    required this.id,
    required this.amount,
    required this.recoveredAmount,
    required this.remainingAmount,
    required this.status,
    required this.advancedAt,
    required this.beneficiary,
    required this.contribution,
  });

  factory ClientGroupAdvance.fromMap(Map<dynamic, dynamic> map) {
    return ClientGroupAdvance(
      id: '${map['id'] ?? ''}',
      amount: _toDouble(map['amount']),
      recoveredAmount: _toDouble(map['recoveredAmount']),
      remainingAmount: _toDouble(map['remainingAmount']),
      status: '${map['status'] ?? 'outstanding'}',
      advancedAt: _toDate(map['advancedAt']),
      beneficiary: map['beneficiary'] is Map
          ? ClientGroupAdvanceParty.fromMap(
              Map<dynamic, dynamic>.from(map['beneficiary'] as Map),
            )
          : null,
      contribution: map['contribution'] is Map
          ? ClientGroupAdvanceContribution.fromMap(
              Map<dynamic, dynamic>.from(map['contribution'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'recoveredAmount': recoveredAmount,
      'remainingAmount': remainingAmount,
      'status': status,
      'advancedAt': advancedAt?.toIso8601String(),
      'beneficiary': beneficiary?.toMap(),
      'contribution': contribution?.toMap(),
    };
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

class ClientGroupAdvanceParty {
  final String id;
  final String displayName;

  const ClientGroupAdvanceParty({
    required this.id,
    required this.displayName,
  });

  factory ClientGroupAdvanceParty.fromMap(Map<dynamic, dynamic> map) {
    return ClientGroupAdvanceParty(
      id: '${map['id'] ?? ''}',
      displayName: '${map['displayName'] ?? ''}',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
    };
  }
}

class ClientGroupAdvanceContribution {
  final String id;
  final int turnNumber;
  final DateTime? dueDate;

  const ClientGroupAdvanceContribution({
    required this.id,
    required this.turnNumber,
    required this.dueDate,
  });

  factory ClientGroupAdvanceContribution.fromMap(Map<dynamic, dynamic> map) {
    return ClientGroupAdvanceContribution(
      id: '${map['id'] ?? ''}',
      turnNumber: int.tryParse('${map['turnNumber'] ?? ''}') ?? 0,
      dueDate: ClientGroupAdvance._toDate(map['dueDate']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'turnNumber': turnNumber,
      'dueDate': dueDate?.toIso8601String(),
    };
  }
}
