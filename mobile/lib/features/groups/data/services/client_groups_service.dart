import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/groups/data/services/groups_cache_service.dart';
import 'package:mobile/features/groups/domain/entities/client_group_advance.dart';
import 'package:mobile/features/groups/domain/entities/client_group_advance_recovery.dart';
import 'package:mobile/features/groups/domain/entities/client_group_contribution.dart';
import 'package:mobile/features/groups/domain/entities/client_group_membership.dart';

class ClientGroupsService {
  final ApiClient _apiClient;
  final GroupsCacheService _cacheService;

  ClientGroupsService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(),
      _cacheService = GroupsCacheService();

  Future<List<ClientGroupMembership>> fetchMyGroups() async {
    return _readThroughCache<List<ClientGroupMembership>>(
      remote: () async {
        final data = await _apiClient.get('/client/groups') as List<dynamic>;
        final groups = data
            .map(
              (entry) => ClientGroupMembership.fromMap(
                Map<dynamic, dynamic>.from(entry as Map),
              ),
            )
            .toList();
        return groups;
      },
      cached: _cacheService.loadMyGroups,
      save: _cacheService.saveMyGroups,
    );
  }

  Future<List<ClientGroupMembership>> fetchMyGroupRequests() async {
    return _readThroughCache<List<ClientGroupMembership>>(
      remote: () async {
        final data =
            await _apiClient.get('/client/groups/requests') as List<dynamic>;
        final requests = data
            .map(
              (entry) => ClientGroupMembership.fromMap(
                Map<dynamic, dynamic>.from(entry as Map),
              ),
            )
            .toList();
        return requests;
      },
      cached: _cacheService.loadMyGroupRequests,
      save: _cacheService.saveMyGroupRequests,
    );
  }

  Future<ClientGroupMembership> fetchGroupDetail(String groupId) async {
    return _readThroughCache<ClientGroupMembership>(
      remote: () async {
        final data = await _apiClient.get('/client/groups/$groupId')
            as Map<dynamic, dynamic>;
        final group = ClientGroupMembership.fromMap(
          Map<dynamic, dynamic>.from(data),
        );
        return group;
      },
      cached: () => _cacheService.loadGroupDetail(groupId),
      save: (group) => _cacheService.saveGroupDetail(groupId, group),
    );
  }

  Future<List<ClientGroupContribution>> fetchGroupContributions(
    String groupId,
  ) async {
    return _readThroughCache<List<ClientGroupContribution>>(
      remote: () async {
        final data =
            await _apiClient.get('/client/groups/$groupId/contributions')
                as List<dynamic>;
        final contributions = data
            .map(
              (entry) => ClientGroupContribution.fromMap(
                Map<dynamic, dynamic>.from(entry as Map),
              ),
            )
            .toList();
        return contributions;
      },
      cached: () => _cacheService.loadGroupContributions(groupId),
      save: (contributions) =>
          _cacheService.saveGroupContributions(groupId, contributions),
    );
  }

  Future<List<ClientGroupAdvance>> fetchGroupAdvances(
    String groupId,
  ) async {
    return _readThroughCache<List<ClientGroupAdvance>>(
      remote: () async {
        final data = await _apiClient.get('/client/groups/$groupId/advances')
            as List<dynamic>;
        final advances = data
            .map(
              (entry) => ClientGroupAdvance.fromMap(
                Map<dynamic, dynamic>.from(entry as Map),
              ),
            )
            .toList();
        return advances;
      },
      cached: () => _cacheService.loadGroupAdvances(groupId),
      save: (advances) => _cacheService.saveGroupAdvances(groupId, advances),
    );
  }

  Future<List<ClientGroupAdvanceRecovery>> fetchGroupAdvanceRecoveries(
    String groupId,
  ) async {
    return _readThroughCache<List<ClientGroupAdvanceRecovery>>(
      remote: () async {
        final data =
            await _apiClient.get('/client/groups/$groupId/advance-recoveries')
                as List<dynamic>;
        final recoveries = data
            .map(
              (entry) => ClientGroupAdvanceRecovery.fromMap(
                Map<dynamic, dynamic>.from(entry as Map),
              ),
            )
            .toList();
        return recoveries;
      },
      cached: () => _cacheService.loadGroupAdvanceRecoveries(groupId),
      save: (recoveries) =>
          _cacheService.saveGroupAdvanceRecoveries(groupId, recoveries),
    );
  }

  Future<ClientGroupContribution> payContribution(String contributionId) async {
    final data = await _apiClient.post(
          '/client/groups/contributions/$contributionId/pay',
        )
        as Map<dynamic, dynamic>;
    return ClientGroupContribution.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<T> _readThroughCache<T>({
    required Future<T> Function() remote,
    required Future<T?> Function() cached,
    required Future<void> Function(T value) save,
  }) async {
    try {
      final value = await remote();
      await save(value);
      return value;
    } on ApiException catch (error) {
      if (!_shouldUseCache(error)) {
        rethrow;
      }

      final cachedValue = await cached();
      if (cachedValue != null) {
        return cachedValue;
      }

      rethrow;
    }
  }

  bool _shouldUseCache(ApiException error) {
    return error.type == ApiErrorType.network ||
        error.type == ApiErrorType.server ||
        error.type == ApiErrorType.unknown;
  }
}
