import 'package:agent/core/network/api_client.dart';
import 'package:agent/features/groups/domain/entities/agent_group.dart';
import 'package:agent/features/groups/domain/entities/agent_group_contribution.dart';
import 'package:agent/features/groups/domain/entities/agent_group_invitation.dart';
import 'package:agent/features/groups/domain/entities/agent_group_member.dart';

class AgentGroupService {
  final ApiClient _apiClient;

  AgentGroupService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<AgentGroup>> fetchGroups({
    String query = '',
    String status = 'all',
  }) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final encodedStatus = Uri.encodeQueryComponent(status);
    final data =
        await _apiClient.get(
              '/agent/groups?q=$encodedQuery&status=$encodedStatus',
            )
            as List<dynamic>;
    return data
        .map(
          (entry) => AgentGroup.fromMap(
            Map<dynamic, dynamic>.from(entry as Map),
          ),
        )
        .toList();
  }

  Future<AgentGroupInvitation> fetchInvitationLink(String groupId) async {
    final data =
        await _apiClient.get('/agent/groups/$groupId/invitation-link')
            as Map<dynamic, dynamic>;
    return AgentGroupInvitation.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<AgentGroup> fetchGroupDetail(String groupId) async {
    final data =
        await _apiClient.get('/agent/groups/$groupId') as Map<dynamic, dynamic>;
    return AgentGroup.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<AgentGroup> createGroup({
    required String name,
    required int participantCount,
    required int turnIntervalValue,
    required String turnIntervalUnit,
    required double contributionAmount,
    required String plannedStartDate,
    String? description,
  }) async {
    final data = await _apiClient.post(
          '/agent/groups',
          body: {
            'name': name,
            'description': description,
            'participantCount': participantCount,
            'turnIntervalValue': turnIntervalValue,
            'turnIntervalUnit': turnIntervalUnit,
            'contributionAmount': contributionAmount,
            'plannedStartDate': plannedStartDate,
          },
        )
        as Map<dynamic, dynamic>;
    return AgentGroup.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<AgentGroup> updateGroup({
    required String groupId,
    required String name,
    required int participantCount,
    required int turnIntervalValue,
    required String turnIntervalUnit,
    required double contributionAmount,
    required String plannedStartDate,
    String? description,
  }) async {
    final data = await _apiClient.patch(
          '/agent/groups/$groupId',
          body: {
            'name': name,
            'description': description,
            'participantCount': participantCount,
            'turnIntervalValue': turnIntervalValue,
            'turnIntervalUnit': turnIntervalUnit,
            'contributionAmount': contributionAmount,
            'plannedStartDate': plannedStartDate,
          },
        )
        as Map<dynamic, dynamic>;
    return AgentGroup.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<AgentGroup> activateGroup(String groupId) async {
    final data =
        await _apiClient.post('/agent/groups/$groupId/activate')
            as Map<dynamic, dynamic>;
    return AgentGroup.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<AgentGroup> suspendGroup(String groupId) async {
    final data =
        await _apiClient.post('/agent/groups/$groupId/suspend')
            as Map<dynamic, dynamic>;
    return AgentGroup.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<AgentGroup> launchGroup(String groupId) async {
    final data =
        await _apiClient.post('/agent/groups/$groupId/launch')
            as Map<dynamic, dynamic>;
    return AgentGroup.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<AgentGroup> postponeGroupLaunch({
    required String groupId,
    required String plannedStartDate,
  }) async {
    final data = await _apiClient.post(
      '/agent/groups/$groupId/postpone',
      body: {'plannedStartDate': plannedStartDate},
    ) as Map<dynamic, dynamic>;
    return AgentGroup.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<AgentGroup> reduceTargetToCurrentMembers(String groupId) async {
    final data =
        await _apiClient.post('/agent/groups/$groupId/reduce-target')
            as Map<dynamic, dynamic>;
    return AgentGroup.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<AgentGroup> cancelGroupLaunch({
    required String groupId,
    required String reason,
  }) async {
    final data = await _apiClient.post(
      '/agent/groups/$groupId/cancel-launch',
      body: {'reason': reason},
    ) as Map<dynamic, dynamic>;
    return AgentGroup.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<List<AgentGroupMember>> fetchMembers(
    String groupId, {
    String status = 'all',
    String query = '',
  }) async {
    final encodedStatus = Uri.encodeQueryComponent(status);
    final encodedQuery = Uri.encodeQueryComponent(query);
    final data = await _apiClient.get(
          '/agent/groups/$groupId/members?status=$encodedStatus&q=$encodedQuery',
        )
        as List<dynamic>;
    return data
        .map(
          (entry) => AgentGroupMember.fromMap(
            Map<dynamic, dynamic>.from(entry as Map),
          ),
        )
        .toList();
  }

  Future<List<AgentGroupCandidate>> fetchMemberCandidates(
    String groupId, {
    String query = '',
  }) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final data = await _apiClient.get(
          '/agent/groups/$groupId/member-candidates?q=$encodedQuery',
        )
        as List<dynamic>;
    return data
        .map(
          (entry) => AgentGroupCandidate.fromMap(
            Map<dynamic, dynamic>.from(entry as Map),
          ),
        )
        .toList();
  }

  Future<AgentGroupMemberMutationResult> addMember({
    required String groupId,
    required String clientUserId,
  }) async {
    final data = await _apiClient.post(
          '/agent/groups/$groupId/members',
          body: {'clientUserId': clientUserId},
        )
        as Map<dynamic, dynamic>;
    return AgentGroupMemberMutationResult(
      group: AgentGroup.fromMap(
        Map<dynamic, dynamic>.from(data['group'] as Map),
      ),
      member: AgentGroupMember.fromMap(
        Map<dynamic, dynamic>.from(data['member'] as Map),
      ),
    );
  }

  Future<AgentGroupInvitation> fetchMemberInvitationLink({
    required String groupId,
    required String memberId,
  }) async {
    final data =
        await _apiClient.get(
              '/agent/groups/$groupId/members/$memberId/invitation-link',
            )
            as Map<dynamic, dynamic>;
    return AgentGroupInvitation.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<AgentGroup> removeMember({
    required String groupId,
    required String memberId,
    String? reason,
  }) async {
    final data = await _apiClient.post(
          '/agent/groups/$groupId/members/$memberId/remove',
          body: {'reason': reason},
        )
        as Map<dynamic, dynamic>;
    return AgentGroup.fromMap(
      Map<dynamic, dynamic>.from(data['group'] as Map),
    );
  }

  Future<AgentGroupMemberMutationResult> approveMemberRequest({
    required String groupId,
    required String memberId,
  }) async {
    final data = await _apiClient.post('/agent/groups/$groupId/members/$memberId/approve')
        as Map<dynamic, dynamic>;
    return AgentGroupMemberMutationResult(
      group: AgentGroup.fromMap(
        Map<dynamic, dynamic>.from(data['group'] as Map),
      ),
      member: AgentGroupMember.fromMap(
        Map<dynamic, dynamic>.from(data['member'] as Map),
      ),
    );
  }

  Future<AgentGroupMemberMutationResult> rejectMemberRequest({
    required String groupId,
    required String memberId,
    String? reason,
  }) async {
    final data = await _apiClient.post(
          '/agent/groups/$groupId/members/$memberId/reject',
          body: {'reason': reason},
        )
        as Map<dynamic, dynamic>;
    return AgentGroupMemberMutationResult(
      group: AgentGroup.fromMap(
        Map<dynamic, dynamic>.from(data['group'] as Map),
      ),
      member: AgentGroupMember.fromMap(
        Map<dynamic, dynamic>.from(data['member'] as Map),
      ),
    );
  }

  Future<List<AgentGroupMember>> saveTurnOrder({
    required String groupId,
    required List<String> orderedMemberIds,
  }) async {
    final data = await _apiClient.post(
          '/agent/groups/$groupId/turn-order',
          body: {'orderedMemberIds': orderedMemberIds},
        )
        as Map<dynamic, dynamic>;
    final members = data['members'] as List<dynamic>? ?? const [];
    return members
        .map(
          (entry) => AgentGroupMember.fromMap(
            Map<dynamic, dynamic>.from(entry as Map),
          ),
        )
        .toList();
  }

  Future<List<AgentGroupTurn>> fetchContributions(
    String groupId, {
    int? turnNumber,
  }) async {
    final suffix = turnNumber == null ? '' : '?turnNumber=$turnNumber';
    final data =
        await _apiClient.get('/agent/groups/$groupId/contributions$suffix')
            as List<dynamic>;
    return data
        .map(
          (entry) => AgentGroupTurn.fromMap(
            Map<dynamic, dynamic>.from(entry as Map),
          ),
        )
        .toList();
  }

  Future<AgentGroupContribution> payContribution({
    required String groupId,
    required String contributionId,
  }) async {
    final data =
        await _apiClient.post(
              '/agent/groups/$groupId/contributions/$contributionId/pay',
            )
            as Map<dynamic, dynamic>;
    return AgentGroupContribution.fromMap(Map<dynamic, dynamic>.from(data));
  }
}

class AgentGroupMemberMutationResult {
  final AgentGroup group;
  final AgentGroupMember member;

  const AgentGroupMemberMutationResult({
    required this.group,
    required this.member,
  });
}
