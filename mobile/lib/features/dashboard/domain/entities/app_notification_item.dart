enum AppNotificationType { deposit, cycle, goal, marketplace, system }

class AppNotificationItem {
  final String id;
  final AppNotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  const AppNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotificationItem.fromMap(Map<dynamic, dynamic> map) {
    final rawType = map['type'] as String?;
    return AppNotificationItem(
      id: map['id'] as String? ?? DateTime.now().toIso8601String(),
      type: AppNotificationType.values.firstWhere(
        (value) => value.name == rawType,
        orElse: () => AppNotificationType.system,
      ),
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      createdAt: DateTime.parse(
        map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      isRead: map['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  AppNotificationItem copyWith({
    String? id,
    AppNotificationType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
