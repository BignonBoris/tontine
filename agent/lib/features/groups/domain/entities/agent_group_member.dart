class AgentGroupMember {
  final String id;
  final String groupId;
  final String clientUserId;
  final String status;
  final DateTime? joinedAt;
  final int? turnPosition;
  final DateTime? removedAt;
  final String? removalReason;
  final int? minimumEligibleTurn;
  final double? estimatedCapacity;
  final double? activeGroupDebt;
  final double? netEstimatedCapacity;
  final AgentGroupCandidate? client;

  const AgentGroupMember({
    required this.id,
    required this.groupId,
    required this.clientUserId,
    required this.status,
    required this.joinedAt,
    required this.turnPosition,
    required this.removedAt,
    required this.removalReason,
    required this.minimumEligibleTurn,
    required this.estimatedCapacity,
    required this.activeGroupDebt,
    required this.netEstimatedCapacity,
    required this.client,
  });

  bool get isActive => status == 'active';
  bool get isRequested => status == 'requested';
  bool get isInvited => status == 'invited';
  bool get isDeclined => status == 'declined';
  bool get isRejected => status == 'rejected';
  bool get isRemoved => status == 'removed';

  factory AgentGroupMember.fromMap(Map<dynamic, dynamic> map) {
    return AgentGroupMember(
      id: '${map['id'] ?? ''}',
      groupId: '${map['groupId'] ?? ''}',
      clientUserId: '${map['clientUserId'] ?? ''}',
      status: '${map['status'] ?? 'active'}',
      joinedAt: _toDate(map['joinedAt']),
      turnPosition: _toInt(map['turnPosition']),
      removedAt: _toDate(map['removedAt']),
      removalReason: map['removalReason']?.toString(),
      minimumEligibleTurn: _toInt(map['minimumEligibleTurn']),
      estimatedCapacity: _toDouble(map['estimatedCapacity']),
      activeGroupDebt: _toDouble(map['activeGroupDebt']),
      netEstimatedCapacity: _toDouble(map['netEstimatedCapacity']),
      client: map['client'] is Map
          ? AgentGroupCandidate.fromMap(
              Map<dynamic, dynamic>.from(map['client'] as Map),
            )
          : null,
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}

class AgentGroupCandidate {
  final String id;
  final String displayName;
  final String phoneNumber;
  final String? address;
  final DateTime? memberSince;
  final int? minimumEligibleTurn;
  final double? estimatedCapacity;
  final double? activeGroupDebt;
  final double? netEstimatedCapacity;
  final bool canBeRanked;

  const AgentGroupCandidate({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    required this.address,
    required this.memberSince,
    required this.minimumEligibleTurn,
    required this.estimatedCapacity,
    required this.activeGroupDebt,
    required this.netEstimatedCapacity,
    required this.canBeRanked,
  });

  factory AgentGroupCandidate.fromMap(Map<dynamic, dynamic> map) {
    return AgentGroupCandidate(
      id: '${map['id'] ?? ''}',
      displayName: '${map['displayName'] ?? ''}',
      phoneNumber: '${map['phoneNumber'] ?? ''}',
      address: map['address']?.toString(),
      memberSince: AgentGroupMember._toDate(map['memberSince']),
      minimumEligibleTurn: AgentGroupMember._toInt(map['minimumEligibleTurn']),
      estimatedCapacity: AgentGroupMember._toDouble(map['estimatedCapacity']),
      activeGroupDebt: AgentGroupMember._toDouble(map['activeGroupDebt']),
      netEstimatedCapacity: AgentGroupMember._toDouble(map['netEstimatedCapacity']),
      canBeRanked: map['canBeRanked'] == true,
    );
  }
}
