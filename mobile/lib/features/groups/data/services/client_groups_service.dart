import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/groups/domain/entities/client_group_advance.dart';
import 'package:mobile/features/groups/domain/entities/client_group_advance_recovery.dart';
import 'package:mobile/features/groups/domain/entities/client_group_contribution.dart';
import 'package:mobile/features/groups/domain/entities/client_group_membership.dart';

class ClientGroupsService {
  final ApiClient _apiClient;

  ClientGroupsService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<ClientGroupMembership>> fetchMyGroups() async {
    final data = await _apiClient.get('/client/groups') as List<dynamic>;
    return data
        .map(
          (entry) => ClientGroupMembership.fromMap(
            Map<dynamic, dynamic>.from(entry as Map),
          ),
        )
        .toList();
  }

  Future<List<ClientGroupMembership>> fetchMyGroupRequests() async {
    final data = await _apiClient.get('/client/groups/requests') as List<dynamic>;
    return data
        .map(
          (entry) => ClientGroupMembership.fromMap(
            Map<dynamic, dynamic>.from(entry as Map),
          ),
        )
        .toList();
  }

  Future<ClientGroupMembership> fetchGroupDetail(String groupId) async {
    final data =
        await _apiClient.get('/client/groups/$groupId') as Map<dynamic, dynamic>;
    return ClientGroupMembership.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<List<ClientGroupContribution>> fetchGroupContributions(
    String groupId,
  ) async {
    final data =
        await _apiClient.get('/client/groups/$groupId/contributions')
            as List<dynamic>;
    return data
        .map(
          (entry) => ClientGroupContribution.fromMap(
            Map<dynamic, dynamic>.from(entry as Map),
          ),
        )
        .toList();
  }

  Future<List<ClientGroupAdvance>> fetchGroupAdvances(
    String groupId,
  ) async {
    final data =
        await _apiClient.get('/client/groups/$groupId/advances')
            as List<dynamic>;
    return data
        .map(
          (entry) => ClientGroupAdvance.fromMap(
            Map<dynamic, dynamic>.from(entry as Map),
          ),
        )
        .toList();
  }

  Future<List<ClientGroupAdvanceRecovery>> fetchGroupAdvanceRecoveries(
    String groupId,
  ) async {
    final data =
        await _apiClient.get('/client/groups/$groupId/advance-recoveries')
            as List<dynamic>;
    return data
        .map(
          (entry) => ClientGroupAdvanceRecovery.fromMap(
            Map<dynamic, dynamic>.from(entry as Map),
          ),
        )
        .toList();
  }

  Future<ClientGroupContribution> payContribution(String contributionId) async {
    final data = await _apiClient.post(
          '/client/groups/contributions/$contributionId/pay',
        )
        as Map<dynamic, dynamic>;
    return ClientGroupContribution.fromMap(Map<dynamic, dynamic>.from(data));
  }
}
