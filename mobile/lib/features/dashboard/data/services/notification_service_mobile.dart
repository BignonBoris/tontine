import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static int _nextNotificationId = DateTime.now().millisecondsSinceEpoch;

  static Future<void> init() async {
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Le clic sur la notification peut etre traite plus tard si besoin.
      },
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  static int _generateNotificationId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now <= _nextNotificationId) {
      _nextNotificationId += 1;
      return _nextNotificationId;
    }

    _nextNotificationId = now;
    return _nextNotificationId;
  }

  static Future<void> showInstantNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'tontine_channel',
          'Alertes VizioBox',
          channelDescription: 'Notifications pour les operations financieres',
          importance: Importance.max,
          priority: Priority.high,
        );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: _generateNotificationId(),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  static Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime date,
  ) async {
    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(date, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'tontine_scheduled',
          'Rappels VizioBox',
          channelDescription: 'Notifications de rappel d echeance',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
