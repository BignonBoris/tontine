import 'package:agent/core/network/api_client.dart';
import 'package:agent/features/home/domain/entities/agent_overview.dart';

class AgentDashboardService {
  final ApiClient _apiClient;

  AgentDashboardService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<AgentOverview> fetchOverview() async {
    final data =
        await _apiClient.get('/agent/dashboard') as Map<dynamic, dynamic>;
    return AgentOverview.fromMap(Map<dynamic, dynamic>.from(data));
  }
}
