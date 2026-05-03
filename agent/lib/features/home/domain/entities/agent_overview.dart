class AgentOverview {
  final int operationsToday;
  final int pendingCount;
  final double totalAmountToday;
  final int myClientsCount;

  const AgentOverview({
    required this.operationsToday,
    required this.pendingCount,
    required this.totalAmountToday,
    required this.myClientsCount,
  });

  factory AgentOverview.fromMap(Map<dynamic, dynamic> map) {
    return AgentOverview(
      operationsToday: _toInt(map['operationsToday']),
      pendingCount: _toInt(map['pendingCount']),
      totalAmountToday: _toDouble(map['totalAmountToday']),
      myClientsCount: _toInt(map['myClientsCount']),
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
