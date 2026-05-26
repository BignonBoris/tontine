class AgentGroupContribution {
  final String id;
  final String groupId;
  final String memberId;
  final String beneficiaryMemberId;
  final int turnNumber;
  final DateTime? dueDate;
  final double amount;
  final String status;
  final String? paymentSource;
  final DateTime? paidAt;
  final AgentGroupContributionParty? member;
  final AgentGroupContributionParty? beneficiary;

  const AgentGroupContribution({
    required this.id,
    required this.groupId,
    required this.memberId,
    required this.beneficiaryMemberId,
    required this.turnNumber,
    required this.dueDate,
    required this.amount,
    required this.status,
    required this.paymentSource,
    required this.paidAt,
    required this.member,
    required this.beneficiary,
  });

  bool get isPaid => status == 'paid';
  bool get isMissed => status == 'missed';

  factory AgentGroupContribution.fromMap(Map<dynamic, dynamic> map) {
    return AgentGroupContribution(
      id: '${map['id'] ?? ''}',
      groupId: '${map['groupId'] ?? ''}',
      memberId: '${map['memberId'] ?? ''}',
      beneficiaryMemberId: '${map['beneficiaryMemberId'] ?? ''}',
      turnNumber: _toInt(map['turnNumber']),
      dueDate: _toDate(map['dueDate']),
      amount: _toDouble(map['amount']),
      status: '${map['status'] ?? 'pending'}',
      paymentSource: map['paymentSource']?.toString(),
      paidAt: _toDate(map['paidAt']),
      member: map['member'] is Map
          ? AgentGroupContributionParty.fromMap(
              Map<dynamic, dynamic>.from(map['member'] as Map),
            )
          : null,
      beneficiary: map['beneficiary'] is Map
          ? AgentGroupContributionParty.fromMap(
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

class AgentGroupContributionParty {
  final String id;
  final String displayName;
  final String phoneNumber;

  const AgentGroupContributionParty({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
  });

  factory AgentGroupContributionParty.fromMap(Map<dynamic, dynamic> map) {
    return AgentGroupContributionParty(
      id: '${map['id'] ?? ''}',
      displayName: '${map['displayName'] ?? ''}',
      phoneNumber: '${map['phoneNumber'] ?? ''}',
    );
  }
}

class AgentGroupTurn {
  final String id;
  final int turnNumber;
  final DateTime? dueDate;
  final double amount;
  final String status;
  final String? payoutMethod;
  final DateTime? payoutAt;
  final AgentGroupContributionParty? beneficiary;
  final List<AgentGroupContribution> contributions;

  const AgentGroupTurn({
    required this.id,
    required this.turnNumber,
    required this.dueDate,
    required this.amount,
    required this.status,
    required this.payoutMethod,
    required this.payoutAt,
    required this.beneficiary,
    required this.contributions,
  });

  int get paidCount => contributions.where((item) => item.isPaid).length;
  int get totalCount => contributions.length;
  bool get isReadyForPayout => status == 'ready';
  bool get isPaidOut => status == 'paid';
  bool get isBlocked => status == 'blocked';

  factory AgentGroupTurn.fromMap(Map<dynamic, dynamic> map) {
    final items = map['contributions'] as List<dynamic>? ?? const [];
    return AgentGroupTurn(
      id: '${map['id'] ?? ''}',
      turnNumber: AgentGroupContribution._toInt(map['turnNumber']),
      dueDate: AgentGroupContribution._toDate(map['dueDate']),
      amount: AgentGroupContribution._toDouble(map['amount']),
      status: '${map['status'] ?? 'collecting'}',
      payoutMethod: map['payoutMethod']?.toString(),
      payoutAt: AgentGroupContribution._toDate(map['payoutAt']),
      beneficiary: map['beneficiary'] is Map
          ? AgentGroupContributionParty.fromMap(
              Map<dynamic, dynamic>.from(map['beneficiary'] as Map),
            )
          : null,
      contributions: items
          .map(
            (entry) => AgentGroupContribution.fromMap(
              Map<dynamic, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
    );
  }
}
