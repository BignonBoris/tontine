import 'package:agent/core/network/api_client.dart';
import 'package:agent/features/clients/domain/entities/agent_client.dart';

class AgentClientService {
  final ApiClient _apiClient;

  AgentClientService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<AgentClient>> searchClients(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final data = await _apiClient.get('/agent/clients?q=$encodedQuery')
        as List<dynamic>;
    return _mapClients(data);
  }

  Future<List<AgentClient>> fetchMyClients({
    String query = '',
    String filter = 'all',
  }) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final encodedFilter = Uri.encodeQueryComponent(filter);
    final data = await _apiClient.get(
          '/agent/clients/mine?q=$encodedQuery&filter=$encodedFilter',
        )
        as List<dynamic>;
    return _mapClients(data);
  }

  Future<AgentClient> fetchMyClientDetail(String clientId) async {
    final data =
        await _apiClient.get('/agent/clients/mine/$clientId')
            as Map<dynamic, dynamic>;
    return AgentClient.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<AgentClient> createClient({
    required String displayName,
    required String phoneNumber,
    required String address,
    required double stakeAmount,
    double initialDeposit = 0,
  }) async {
    final data = await _apiClient.post(
          '/agent/clients',
          body: {
            'displayName': displayName,
            'phoneNumber': phoneNumber.replaceAll(RegExp(r'\D'), ''),
            'address': address,
            'stakeAmount': stakeAmount,
            'initialDeposit': initialDeposit,
          },
        )
        as Map<dynamic, dynamic>;
    return AgentClient.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<AgentClient> startTontine({
    required String clientId,
    required double stakeAmount,
    double initialDeposit = 0,
  }) async {
    final data = await _apiClient.post(
          '/agent/clients/$clientId/start-tontine',
          body: {
            'stakeAmount': stakeAmount,
            'initialDeposit': initialDeposit,
          },
        )
        as Map<dynamic, dynamic>;
    return AgentClient.fromMap(Map<dynamic, dynamic>.from(data));
  }

  List<AgentClient> _mapClients(List<dynamic> data) {
    return data
        .map(
          (entry) => AgentClient.fromMap(Map<dynamic, dynamic>.from(entry as Map)),
        )
        .toList();
  }
}
