import 'package:mobile/features/groups/data/services/client_group_invitations_service.dart';
import 'package:mobile/features/groups/data/services/client_groups_service.dart';
import 'package:mobile/features/groups/domain/entities/client_group_membership.dart';

class ReadModelBootstrapService {
  final ClientGroupsService _groupsService;
  final ClientGroupInvitationsService _invitationsService;

  ReadModelBootstrapService({
    ClientGroupsService? groupsService,
    ClientGroupInvitationsService? invitationsService,
  })  : _groupsService = groupsService ?? ClientGroupsService(),
        _invitationsService = invitationsService ?? ClientGroupInvitationsService();

  Future<void> warmUpCurrentSession() async {
    await Future.wait([
      _warmUpGroups(),
      _warmUpInvitations(),
    ]);
  }

  Future<void> _warmUpGroups() async {
    final memberships = <ClientGroupMembership>[];

    try {
      memberships.addAll(await _groupsService.fetchMyGroups());
    } catch (_) {}

    try {
      memberships.addAll(await _groupsService.fetchMyGroupRequests());
    } catch (_) {}

    final seenGroupIds = <String>{};
    for (final group in memberships) {
      if (!seenGroupIds.add(group.id)) {
        continue;
      }
      await _warmUpGroup(group.id);
    }
  }

  Future<void> _warmUpGroup(String groupId) async {
    try {
      await _groupsService.fetchGroupDetail(groupId);
    } catch (_) {}

    try {
      await _groupsService.fetchGroupContributions(groupId);
    } catch (_) {}

    try {
      await _groupsService.fetchGroupAdvances(groupId);
    } catch (_) {}

    try {
      await _groupsService.fetchGroupAdvanceRecoveries(groupId);
    } catch (_) {}
  }

  Future<void> _warmUpInvitations() async {
    try {
      await _invitationsService.fetchPendingInvitations();
    } catch (_) {}
  }
}
