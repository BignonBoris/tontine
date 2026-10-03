import 'package:agent/core/network/api_client.dart';
import 'package:agent/features/clients/domain/entities/agent_client.dart';
import 'package:agent/features/clients/data/services/offline_kyc_service.dart';

class AgentClientService {
  final ApiClient _apiClient;

  AgentClientService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<AgentClient>> searchClients(String query, {String type = 'phone'}) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final encodedType = Uri.encodeQueryComponent(type);
    final data = await _apiClient.get('/agent/clients?q=$encodedQuery&type=$encodedType')
        as List<dynamic>;
    return _mapClients(data);
  }

  Future<List<AgentClient>> fetchMyClients({
    String query = '',
    String filter = 'all',
  }) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final encodedFilter = Uri.encodeQueryComponent(filter);
    
    // 1. Fetch remote clients
    List<AgentClient> remoteClients = [];
    try {
      final data = await _apiClient.get(
            '/agent/clients/mine?q=$encodedQuery&filter=$encodedFilter',
          )
          as List<dynamic>;
      remoteClients = _mapClients(data);
    } catch (e) {
      print('Erreur fetchMyClients remote: $e');
    }

    // 2. Fetch local offline clients
    final offlineService = OfflineKycService();
    final pendingEnrollments = await offlineService.getPendingEnrollments();
    
    final localClients = pendingEnrollments.map((model) {
      return AgentClient(
        id: model.clientId,
        displayName: '${model.firstName} ${model.lastName}'.trim(),
        phoneNumber: model.phoneNumber,
        accountType: 'Tontine', // Default
        memberSince: model.createdAt,
        cycleStatus: 'En attente de synchro',
      );
    }).toList();

    // 3. Merge both
    return [...localClients, ...remoteClients];
  }

  Future<AgentClient> fetchMyClientDetail(String clientId) async {
    final data =
        await _apiClient.get('/agent/clients/mine/$clientId')
            as Map<dynamic, dynamic>;
    return AgentClient.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<AgentClient> createClient({
    required String displayName,
    String? phoneNumber,
    required String address,
    required double stakeAmount,
    double initialDeposit = 0,
  }) async {
    final normalizedPhone = phoneNumber == null
        ? ''
        : phoneNumber.replaceAll(RegExp(r'\D'), '');
    final data = await _apiClient.post(
          '/agent/clients',
          body: {
            'displayName': displayName,
            'address': address,
            'stakeAmount': stakeAmount,
            'initialDeposit': initialDeposit,
            if (normalizedPhone.isNotEmpty) 'phoneNumber': normalizedPhone,
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

  Future<AgentClient> closeTontine({
    required String clientId,
    required String pinCode,
  }) async {
    final data = await _apiClient.post(
          '/agent/clients/$clientId/close-tontine',
          body: {
            'pinCode': pinCode,
          },
        )
        as Map<dynamic, dynamic>;
    return AgentClient.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<AgentClient> updatePhone({
    required String clientId,
    required String phoneNumber,
  }) async {
    final normalizedPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final data = await _apiClient.put(
      '/agent/clients/$clientId/phone',
      body: {'phoneNumber': normalizedPhone},
    ) as Map<dynamic, dynamic>;
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
