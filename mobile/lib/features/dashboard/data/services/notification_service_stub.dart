// Stub pour la plateforme web — aucune notification locale disponible
class NotificationService {
  static Future<void> init() async {}

  static Future<void> showInstantNotification(
    String title,
    String body,
  ) async {}

  static Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime date,
  ) async {}
}
