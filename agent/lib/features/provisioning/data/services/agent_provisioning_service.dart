import 'package:agent/core/network/api_client.dart';
import 'package:agent/features/provisioning/domain/entities/agent_provisioning.dart';

class AgentProvisioningService {
  final ApiClient _apiClient;

  AgentProvisioningService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<AgentProvisioning>> fetchProvisionings() async {
    final data = await _apiClient.get('/agent/provisionings') as List<dynamic>;
    return data
        .map(
          (entry) => AgentProvisioning.fromMap(
            Map<dynamic, dynamic>.from(entry as Map),
          ),
        )
        .toList();
  }

  Future<AgentProvisioning> createProvisioning({
    required String clientUserId,
    required double amount,
    String? notes,
  }) async {
    final data = await _apiClient.post(
      '/agent/provisionings',
      body: {
        'clientUserId': clientUserId,
        'amount': amount,
        'notes': notes,
      },
    ) as Map<dynamic, dynamic>;
    return AgentProvisioning.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<AgentProvisioning> reverseProvisioning({
    required String provisioningId,
    required String reason,
  }) async {
    final data = await _apiClient.post(
      '/agent/provisionings/$provisioningId/reverse',
      body: {
        'reason': reason,
      },
    ) as Map<dynamic, dynamic>;
    return AgentProvisioning.fromMap(Map<dynamic, dynamic>.from(data));
  }
}
