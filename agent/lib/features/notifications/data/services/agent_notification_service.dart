import 'package:agent/core/network/api_client.dart';
import 'package:agent/features/notifications/domain/entities/agent_notification_item.dart';

class AgentNotificationService {
  final ApiClient _apiClient;

  AgentNotificationService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<AgentNotificationItem>> fetchNotifications() async {
    final data = await _apiClient.get('/notifications');
    final notifications = data is List ? List<dynamic>.from(data) : const <dynamic>[];
    return notifications
        .map((entry) => AgentNotificationItem.fromMap(_asMap(entry)))
        .toList();
  }

  Future<void> markNotificationAsRead(String notificationId) {
    return _apiClient.post('/notifications/$notificationId/read');
  }

  Future<void> markAllNotificationsAsRead() {
    return _apiClient.post('/notifications/read-all');
  }

  Map<dynamic, dynamic> _asMap(dynamic raw) {
    if (raw is Map) {
      return Map<dynamic, dynamic>.from(raw);
    }
    return <dynamic, dynamic>{};
  }
}
