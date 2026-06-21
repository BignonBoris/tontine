import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/groups/data/services/groups_cache_service.dart';
import 'package:mobile/features/groups/domain/entities/group_invitation_preview.dart';

class ClientGroupInvitationsService {
  final ApiClient _apiClient;
  final GroupsCacheService _cacheService;

  ClientGroupInvitationsService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(),
      _cacheService = GroupsCacheService();

  Future<List<GroupInvitationPreview>> fetchPendingInvitations() async {
    return _readThroughCache<List<GroupInvitationPreview>>(
      remote: () async {
        final data =
            await _apiClient.get('/client/group-invitations') as List<dynamic>;
        final invitations = data
            .map(
              (entry) => GroupInvitationPreview.fromMap(
                Map<dynamic, dynamic>.from(entry as Map),
              ),
            )
            .toList();
        return invitations;
      },
      cached: _cacheService.loadPendingInvitations,
      save: _cacheService.savePendingInvitations,
    );
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
