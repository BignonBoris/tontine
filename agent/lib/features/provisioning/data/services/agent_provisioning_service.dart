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
    // Offline security fields — sent to backend for audit trail
    String? offlineHash,
    String? previousHash,
    DateTime? secureTimestamp,
  }) async {
    final data = await _apiClient.post(
      '/agent/provisionings',
      body: {
        'clientUserId': clientUserId,
        'amount': amount,
        'notes': notes,
        'offlineHash': offlineHash,
        'previousHash': previousHash,
        'secureTimestamp': secureTimestamp?.toUtc().toIso8601String(),
      },
    ) as Map<dynamic, dynamic>;
    return AgentProvisioning.fromMap(Map<dynamic, dynamic>.from(data));
  }
}
