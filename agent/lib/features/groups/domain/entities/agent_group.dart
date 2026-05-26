class AgentGroup {
  final String id;
  final String reference;
  final String name;
  final String? description;
  final int participantCount;
  final int memberCount;
  final int turnIntervalValue;
  final String turnIntervalUnit;
  final double contributionAmount;
  final DateTime? plannedStartDate;
  final String launchStatus;
  final DateTime? startedAt;
  final DateTime? launchCancelledAt;
  final String? launchCancellationReason;
  final String status;
  final String agentProfileId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AgentGroup({
    required this.id,
    required this.reference,
    required this.name,
    required this.description,
    required this.participantCount,
    required this.memberCount,
    required this.turnIntervalValue,
    required this.turnIntervalUnit,
    required this.contributionAmount,
    required this.plannedStartDate,
    required this.launchStatus,
    required this.startedAt,
    required this.launchCancelledAt,
    required this.launchCancellationReason,
    required this.status,
    required this.agentProfileId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get canLaunch => launchStatus == 'ready';
  bool get isStarted => launchStatus == 'started';

  factory AgentGroup.fromMap(Map<dynamic, dynamic> map) {
    return AgentGroup(
      id: '${map['id'] ?? ''}',
      reference: '${map['reference'] ?? ''}',
      name: '${map['name'] ?? ''}',
      description: map['description']?.toString(),
      participantCount: _toInt(map['participantCount']),
      memberCount: _toInt(map['memberCount']),
      turnIntervalValue: _toInt(map['turnIntervalValue']),
      turnIntervalUnit: '${map['turnIntervalUnit'] ?? 'month'}',
      contributionAmount: _toDouble(map['contributionAmount']),
      plannedStartDate: _toDate(map['plannedStartDate']),
      launchStatus: '${map['launchStatus'] ?? 'collecting'}',
      startedAt: _toDate(map['startedAt']),
      launchCancelledAt: _toDate(map['launchCancelledAt']),
      launchCancellationReason: map['launchCancellationReason']?.toString(),
      status: '${map['status'] ?? 'active'}',
      agentProfileId: '${map['agentProfileId'] ?? ''}',
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
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
}
