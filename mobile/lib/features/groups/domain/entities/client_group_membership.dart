class ClientGroupMembership {
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
  final String status;
  final DateTime? joinedAt;
  final ClientGroupAgent? agent;

  const ClientGroupMembership({
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
    required this.status,
    required this.joinedAt,
    required this.agent,
  });

  factory ClientGroupMembership.fromMap(Map<dynamic, dynamic> map) {
    final membership = Map<dynamic, dynamic>.from(
      map['membership'] as Map? ?? const {},
    );
    final agentMap = map['agent'] is Map
        ? Map<dynamic, dynamic>.from(map['agent'] as Map)
        : null;

    return ClientGroupMembership(
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
      status: '${membership['status'] ?? map['status'] ?? 'active'}',
      joinedAt: _toDate(membership['joinedAt']),
      agent: agentMap == null ? null : ClientGroupAgent.fromMap(agentMap),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reference': reference,
      'name': name,
      'description': description,
      'participantCount': participantCount,
      'memberCount': memberCount,
      'turnIntervalValue': turnIntervalValue,
      'turnIntervalUnit': turnIntervalUnit,
      'contributionAmount': contributionAmount,
      'plannedStartDate': plannedStartDate?.toIso8601String(),
      'launchStatus': launchStatus,
      'startedAt': startedAt?.toIso8601String(),
      'status': status,
      'membership': {
        'status': status,
        'joinedAt': joinedAt?.toIso8601String(),
      },
      'agent': agent?.toMap(),
    };
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

class ClientGroupAgent {
  final String id;
  final String displayName;
  final String phoneNumber;

  const ClientGroupAgent({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
  });

  factory ClientGroupAgent.fromMap(Map<dynamic, dynamic> map) {
    return ClientGroupAgent(
      id: '${map['id'] ?? ''}',
      displayName: '${map['displayName'] ?? ''}',
      phoneNumber: '${map['phoneNumber'] ?? ''}',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
    };
  }
}
