import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/groups/domain/entities/group_invitation_preview.dart';

class ClientGroupInvitationsService {
  final ApiClient _apiClient;

  ClientGroupInvitationsService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<GroupInvitationPreview>> fetchPendingInvitations() async {
    final data =
        await _apiClient.get('/client/group-invitations') as List<dynamic>;
    return data
        .map(
          (entry) => GroupInvitationPreview.fromMap(
            Map<dynamic, dynamic>.from(entry as Map),
          ),
        )
        .toList();
  }
}
