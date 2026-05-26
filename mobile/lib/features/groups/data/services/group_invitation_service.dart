import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/groups/domain/entities/group_invitation_preview.dart';

class GroupInvitationService {
  final ApiClient _apiClient;

  GroupInvitationService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<GroupInvitationPreview> fetchPreview(String token) async {
    final data = await _apiClient.get(
          '/group-invitations/$token',
          authenticated: false,
        )
        as Map<dynamic, dynamic>;
    return GroupInvitationPreview.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<GroupInvitationPreview> accept(String token) async {
    final data = await _apiClient.post('/group-invitations/$token/accept')
        as Map<dynamic, dynamic>;
    final group = Map<dynamic, dynamic>.from(data['group'] as Map? ?? const {});
    return GroupInvitationPreview(
      token: token,
      shareUrl: '',
      previewUrl: '',
      invitationType: '${data['invitationType'] ?? 'open'}',
      membershipStatus: data['memberStatus']?.toString(),
      groupId: '${group['id'] ?? ''}',
      reference: '${group['reference'] ?? ''}',
      groupName: '${group['name'] ?? ''}',
      participantCount: _toInt(group['participantCount']),
      memberCount: _toInt(group['memberCount']),
      remainingSlots: 0,
      plannedStartDate: _toDate(group['plannedStartDate']),
      launchStatus: '${group['launchStatus'] ?? 'collecting'}',
      contributionAmount: _toDouble(group['contributionAmount']),
      turnIntervalValue: _toInt(group['turnIntervalValue']),
      turnIntervalUnit: '${group['turnIntervalUnit'] ?? 'month'}',
      description: group['description']?.toString(),
    );
  }

  Future<void> decline(String token) async {
    await _apiClient.post('/group-invitations/$token/decline');
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
