import 'package:agent/core/network/api_client.dart';
import 'package:agent/features/home/domain/entities/agent_overview.dart';

class AgentDashboardService {
  final ApiClient _apiClient;

  AgentDashboardService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<AgentOverview> fetchOverview() async {
    final overviewData =
        await _apiClient.get('/agent/dashboard') as Map<dynamic, dynamic>;
    final merged = Map<dynamic, dynamic>.from(overviewData);

    try {
      final commissionData =
          await _apiClient.get('/agent/dashboard/commissions')
              as Map<dynamic, dynamic>;
      final wallet =
          Map<dynamic, dynamic>.from(
            (commissionData['wallet'] as Map?) ?? const <dynamic, dynamic>{},
          );
      merged['commissionBalance'] = wallet['balance'];
      merged['commissionPayableBalance'] = wallet['payableBalance'];
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        rethrow;
      }
      merged['commissionBalance'] = 0;
      merged['commissionPayableBalance'] = 0;
    } catch (_) {
      merged['commissionBalance'] = 0;
      merged['commissionPayableBalance'] = 0;
    }

    try {
      final notificationsData = await _apiClient.get('/notifications');
      final notifications = notificationsData is List
          ? List<dynamic>.from(notificationsData)
          : const <dynamic>[];
      merged['unreadNotificationsCount'] = notifications.where((entry) {
        final map = entry is Map
            ? Map<dynamic, dynamic>.from(entry)
            : const <dynamic, dynamic>{};
        return map['isRead'] != true;
      }).length;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        rethrow;
      }
      merged['unreadNotificationsCount'] = 0;
    } catch (_) {
      merged['unreadNotificationsCount'] = 0;
    }

    return AgentOverview.fromMap(merged);
  }
}
