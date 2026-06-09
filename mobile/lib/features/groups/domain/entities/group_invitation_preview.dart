class GroupInvitationPreview {
  final String token;
  final String shareUrl;
  final String previewUrl;
  final String invitationType;
  final String? membershipStatus;
  final String groupId;
  final String reference;
  final String groupName;
  final int participantCount;
  final int memberCount;
  final int remainingSlots;
  final DateTime? plannedStartDate;
  final String launchStatus;
  final double contributionAmount;
  final int turnIntervalValue;
  final String turnIntervalUnit;
  final String? description;

  const GroupInvitationPreview({
    required this.token,
    required this.shareUrl,
    required this.previewUrl,
    required this.invitationType,
    required this.membershipStatus,
    required this.groupId,
    required this.reference,
    required this.groupName,
    required this.participantCount,
    required this.memberCount,
    required this.remainingSlots,
    required this.plannedStartDate,
    required this.launchStatus,
    required this.contributionAmount,
    required this.turnIntervalValue,
    required this.turnIntervalUnit,
    required this.description,
  });

  factory GroupInvitationPreview.fromMap(Map<dynamic, dynamic> map) {
    final invitation = Map<dynamic, dynamic>.from(
      map['invitation'] as Map? ?? const {},
    );
    return GroupInvitationPreview(
      token: '${map['token'] ?? ''}',
      shareUrl: '${map['shareUrl'] ?? ''}',
      previewUrl: '${map['previewUrl'] ?? ''}',
      invitationType: '${map['invitationType'] ?? 'open'}',
      membershipStatus: map['memberStatus']?.toString(),
      groupId: '${invitation['groupId'] ?? ''}',
      reference: '${invitation['reference'] ?? ''}',
      groupName: '${invitation['groupName'] ?? ''}',
      participantCount: _toInt(invitation['participantCount']),
      memberCount: _toInt(invitation['memberCount']),
      remainingSlots: _toInt(invitation['remainingSlots']),
      plannedStartDate: _toDate(invitation['plannedStartDate']),
      launchStatus: '${invitation['launchStatus'] ?? 'collecting'}',
      contributionAmount: _toDouble(invitation['contributionAmount']),
      turnIntervalValue: _toInt(invitation['turnIntervalValue']),
      turnIntervalUnit: '${invitation['turnIntervalUnit'] ?? 'month'}',
      description: invitation['description']?.toString(),
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
