class AgentGroupAdvance {
  final String id;
  final String groupId;
  final String contributionId;
  final String memberId;
  final String beneficiaryMemberId;
  final String agentProfileId;
  final double amount;
  final double recoveredAmount;
  final double remainingAmount;
  final String status;
  final DateTime? advancedAt;
  final DateTime? recoveredAt;
  final DateTime? lastRecoveredAt;
  final AgentGroupAdvanceParty? member;
  final AgentGroupAdvanceParty? beneficiary;
  final AgentGroupAdvanceContribution? contribution;

  const AgentGroupAdvance({
    required this.id,
    required this.groupId,
    required this.contributionId,
    required this.memberId,
    required this.beneficiaryMemberId,
    required this.agentProfileId,
    required this.amount,
    required this.recoveredAmount,
    required this.remainingAmount,
    required this.status,
    required this.advancedAt,
    required this.recoveredAt,
    required this.lastRecoveredAt,
    required this.member,
    required this.beneficiary,
    required this.contribution,
  });

  bool get isRecovered => status == 'recovered';

  factory AgentGroupAdvance.fromMap(Map<dynamic, dynamic> map) {
    return AgentGroupAdvance(
      id: '${map['id'] ?? ''}',
      groupId: '${map['groupId'] ?? ''}',
      contributionId: '${map['contributionId'] ?? ''}',
      memberId: '${map['memberId'] ?? ''}',
      beneficiaryMemberId: '${map['beneficiaryMemberId'] ?? ''}',
      agentProfileId: '${map['agentProfileId'] ?? ''}',
      amount: _toDouble(map['amount']),
      recoveredAmount: _toDouble(map['recoveredAmount']),
      remainingAmount: _toDouble(map['remainingAmount']),
      status: '${map['status'] ?? 'outstanding'}',
      advancedAt: _toDate(map['advancedAt']),
      recoveredAt: _toDate(map['recoveredAt']),
      lastRecoveredAt: _toDate(map['lastRecoveredAt']),
      member: map['member'] is Map
          ? AgentGroupAdvanceParty.fromMap(
              Map<dynamic, dynamic>.from(map['member'] as Map),
            )
          : null,
      beneficiary: map['beneficiary'] is Map
          ? AgentGroupAdvanceParty.fromMap(
              Map<dynamic, dynamic>.from(map['beneficiary'] as Map),
            )
          : null,
      contribution: map['contribution'] is Map
          ? AgentGroupAdvanceContribution.fromMap(
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

class AgentGroupAdvanceParty {
  final String id;
  final String displayName;
  final String phoneNumber;

  const AgentGroupAdvanceParty({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
  });

  factory AgentGroupAdvanceParty.fromMap(Map<dynamic, dynamic> map) {
    return AgentGroupAdvanceParty(
      id: '${map['id'] ?? ''}',
      displayName: '${map['displayName'] ?? ''}',
      phoneNumber: '${map['phoneNumber'] ?? ''}',
    );
  }
}

class AgentGroupAdvanceContribution {
  final String id;
  final int turnNumber;
  final DateTime? dueDate;
  final String status;
  final String? paymentSource;
  final DateTime? paidAt;

  const AgentGroupAdvanceContribution({
    required this.id,
    required this.turnNumber,
    required this.dueDate,
    required this.status,
    required this.paymentSource,
    required this.paidAt,
  });

  factory AgentGroupAdvanceContribution.fromMap(Map<dynamic, dynamic> map) {
    return AgentGroupAdvanceContribution(
      id: '${map['id'] ?? ''}',
      turnNumber: int.tryParse('${map['turnNumber'] ?? ''}') ?? 0,
      dueDate: AgentGroupAdvance._toDate(map['dueDate']),
      status: '${map['status'] ?? 'pending'}',
      paymentSource: map['paymentSource']?.toString(),
      paidAt: AgentGroupAdvance._toDate(map['paidAt']),
    );
  }
}
