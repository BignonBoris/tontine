enum AgentNotificationType { deposit, cycle, goal, marketplace, system }

class AgentNotificationItem {
  final String id;
  final AgentNotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  const AgentNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  factory AgentNotificationItem.fromMap(Map<dynamic, dynamic> map) {
    final rawType = map['type'] as String? ?? 'system';
    final createdAtRaw = map['createdAtClient'] ?? map['createdAt'];

    return AgentNotificationItem(
      id: map['id'] as String? ?? DateTime.now().toIso8601String(),
      type: AgentNotificationType.values.firstWhere(
        (value) => value.name == rawType,
        orElse: () => AgentNotificationType.system,
      ),
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      createdAt: _parseDate(createdAtRaw),
      isRead: map['isRead'] as bool? ?? false,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse('$value') ?? DateTime.now();
  }
}
