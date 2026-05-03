class AgentClient {
  final String id;
  final String displayName;
  final String phoneNumber;
  final String accountType;
  final String? address;
  final DateTime? memberSince;
  final DateTime? lastOperationAt;
  final bool hasActiveTontine;
  final double currentStakeAmount;
  final String? cycleStatus;
  final double availableBalance;
  final double tontineBalance;
  final List<AgentClientProvisioningSummary> latestProvisionings;

  const AgentClient({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    required this.accountType,
    this.address,
    this.memberSince,
    this.lastOperationAt,
    this.hasActiveTontine = false,
    this.currentStakeAmount = 0,
    this.cycleStatus,
    this.availableBalance = 0,
    this.tontineBalance = 0,
    this.latestProvisionings = const [],
  });

  factory AgentClient.fromMap(Map<dynamic, dynamic> map) {
    return AgentClient(
      id: map['id'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      accountType: map['accountType'] as String? ?? '',
      address: map['address'] as String?,
      memberSince: _toDate(map['memberSince']),
      lastOperationAt: _toDate(map['lastOperationAt']),
      hasActiveTontine: map['hasActiveTontine'] as bool? ?? false,
      currentStakeAmount: _toDouble(map['currentStakeAmount']),
      cycleStatus: map['cycleStatus'] as String?,
      availableBalance: _toDouble(map['availableBalance']),
      tontineBalance: _toDouble(map['tontineBalance']),
      latestProvisionings: (map['latestProvisionings'] as List<dynamic>? ?? const [])
          .map(
            (entry) => AgentClientProvisioningSummary.fromMap(
              Map<dynamic, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }
}

class AgentClientProvisioningSummary {
  final String id;
  final String reference;
  final double amount;
  final String status;
  final DateTime? createdAt;
  final DateTime? validatedAt;

  const AgentClientProvisioningSummary({
    required this.id,
    required this.reference,
    required this.amount,
    required this.status,
    this.createdAt,
    this.validatedAt,
  });

  factory AgentClientProvisioningSummary.fromMap(Map<dynamic, dynamic> map) {
    return AgentClientProvisioningSummary(
      id: map['id'] as String? ?? '',
      reference: map['reference'] as String? ?? '',
      amount: AgentClient._toDouble(map['amount']),
      status: map['status'] as String? ?? 'validated',
      createdAt: AgentClient._toDate(map['createdAt']),
      validatedAt: AgentClient._toDate(map['validatedAt']),
    );
  }
}
