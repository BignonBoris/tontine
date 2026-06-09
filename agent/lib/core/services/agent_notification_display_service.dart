import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AgentNotificationDisplayService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Future<void>? _initializationFuture;
  static int _nextNotificationId = DateTime.now().millisecondsSinceEpoch;

  static Future<void> init() async {
    if (_initialized) {
      return;
    }

    _initializationFuture ??= _initialize().whenComplete(() {
      _initializationFuture = null;
    });
    await _initializationFuture;
  }

  static Future<void> _initialize() async {
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
        // Le clic sur la notification pourra etre traite plus tard si besoin.
      },
    );

    await _notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _initialized = true;
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
    if (!_initialized) {
      await init();
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'tontine_channel',
          'Alertes VizioBox Agent',
          channelDescription:
              'Notifications temps reel pour les operations agent',
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
}
