class AgentOverview {
  final double agentBalance;
  final int operationsToday;
  final int pendingCount;
  final double totalAmountToday;
  final int myClientsCount;
  final double commissionBalance;
  final double commissionPayableBalance;

  const AgentOverview({
    required this.agentBalance,
    required this.operationsToday,
    required this.pendingCount,
    required this.totalAmountToday,
    required this.myClientsCount,
    required this.commissionBalance,
    required this.commissionPayableBalance,
  });

  factory AgentOverview.fromMap(Map<dynamic, dynamic> map) {
    return AgentOverview(
      agentBalance: _toDouble(map['agentBalance']),
      operationsToday: _toInt(map['operationsToday']),
      pendingCount: _toInt(map['pendingCount']),
      totalAmountToday: _toDouble(map['totalAmountToday']),
      myClientsCount: _toInt(map['myClientsCount']),
      commissionBalance: _toDouble(map['commissionBalance']),
      commissionPayableBalance: _toDouble(map['commissionPayableBalance']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }
}
