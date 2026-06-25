import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/network/api_config.dart';
import 'package:mobile/core/storage/session_storage.dart';
import 'package:mobile/features/dashboard/data/services/notification_service.dart';
import 'package:mobile/firebase_options.dart';

class PushNotificationService {
  static final PushNotificationService instance =
      PushNotificationService._internal();

  PushNotificationService._internal();

  bool _firebaseReady = false;
  bool _listenersRegistered = false;
  bool _clearHookRegistered = false;
  bool _clearHookSuspended = false;
  bool _firebaseDisabled = false;
  bool _messagingPermissionHandled = false;
  Future<bool>? _firebaseInitializationFuture;
  int _sessionSyncGeneration = 0;
  String _appName = 'mobile';
  String? _lastRegisteredPushToken;
  String? _lastRegisteredSessionToken;
  String? _lastRegisteredAppName;

  Future<void> start({String appName = 'mobile'}) async {
    if (!_supportsPushNotifications()) {
      return;
    }

    _appName = appName;
    final ready = await _ensureFirebaseReady();
    if (!ready) {
      return;
    }

    await _ensureMessagingPermissions();
    _registerListeners();
    _registerClearHookOnce();
    await syncCurrentToken(appName: appName);
  }

  Future<void> syncCurrentToken({
    String appName = 'mobile',
    bool force = false,
  }) async {
    if (!_supportsPushNotifications()) {
      return;
    }

    _appName = appName;
    final ready = await _ensureFirebaseReady();
    if (!ready) {
      return;
    }

    await _ensureMessagingPermissions();
    _registerListeners();
    _registerClearHookOnce();

    final sessionToken = await SessionStorage.getToken();
    if (sessionToken == null || sessionToken.isEmpty) {
      return;
    }

    final pushToken = await FirebaseMessaging.instance.getToken();
    print("pushToken = " + pushToken.toString());
    if (pushToken == null || pushToken.isEmpty) {
      return;
    }

    if (!force &&
        _lastRegisteredPushToken == pushToken &&
        _lastRegisteredSessionToken == sessionToken &&
        _lastRegisteredAppName == appName) {
      return;
    }

    final syncGeneration = _sessionSyncGeneration;
    try {
      if (syncGeneration != _sessionSyncGeneration) {
        return;
      }

      await _postAuthenticatedJson('/notifications/devices/register', {
        'token': pushToken,
        'platform': _detectPlatform(),
        'appName': appName,
      }, authToken: sessionToken);

      if (syncGeneration != _sessionSyncGeneration) {
        return;
      }

      _lastRegisteredPushToken = pushToken;
      _lastRegisteredSessionToken = sessionToken;
      _lastRegisteredAppName = appName;
    } catch (error) {
      if (kDebugMode) {
        print('Push notification registration failed: $error');
      }
    }
  }

  Future<void> signOut({String? appName}) async {
    if (kIsWeb) {
      _clearLocalCache();
      await SessionStorage.clear();
      return;
    }

    _appName = appName ?? _appName;
    _invalidatePendingSynchronizations();
    _clearHookSuspended = true;
    try {
      final ready = await _ensureFirebaseReady();
      if (ready) {
        await _unregisterCurrentDevice();
        try {
          await FirebaseMessaging.instance.deleteToken();
        } catch (_) {}
      }

      _clearLocalCache();
      await SessionStorage.clear();
    } finally {
      _clearHookSuspended = false;
    }
  }

  Future<void> _handleExternalSessionClear() async {
    if (kIsWeb) {
      _clearLocalCache();
      return;
    }

    _invalidatePendingSynchronizations();
    final ready = await _ensureFirebaseReady();
    if (ready) {
      await _unregisterCurrentDevice();
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }

    _clearLocalCache();
  }

  Future<void> _ensureMessagingPermissions() async {
    if (!_supportsPushNotifications()) {
      return;
    }
    if (_messagingPermissionHandled) {
      return;
    }

    try {
      final NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );
      _messagingPermissionHandled = true;

      if (kDebugMode &&
          settings.authorizationStatus == AuthorizationStatus.denied) {
        print('Push notification permission denied by user.');
      }

      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: true,
              badge: true,
              sound: true,
            );
      }
    } catch (error) {
      if (kDebugMode) {
        print('Push notification permission setup failed: $error');
      }
    }
  }

  void _registerListeners() {
    if (_listenersRegistered) {
      return;
    }

    _listenersRegistered = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final title =
          message.notification?.title ??
          message.data['title']?.toString() ??
          'Nouvelle notification';
      final body =
          message.notification?.body ??
          message.data['message']?.toString() ??
          '';
      final payload = jsonEncode(message.data);

      try {
        await NotificationService.showInstantNotification(
          title,
          body,
          payload: payload,
        );
      } catch (error) {
        if (kDebugMode) {
          print('Foreground push display failed: $error');
        }
      }
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      if (token.isEmpty) {
        return;
      }

      unawaited(syncCurrentToken(appName: _appName, force: true));
    });
  }

  void _registerClearHookOnce() {
    if (_clearHookRegistered) {
      return;
    }

    _clearHookRegistered = true;
    SessionStorage.registerBeforeClearHook(() async {
      if (_clearHookSuspended) {
        return;
      }

      await _handleExternalSessionClear();
    });
  }

  void _clearLocalCache() {
    _lastRegisteredPushToken = null;
    _lastRegisteredSessionToken = null;
    _lastRegisteredAppName = null;
  }

  void _invalidatePendingSynchronizations() {
    _sessionSyncGeneration += 1;
  }

  Future<void> _unregisterCurrentDevice() async {
    final authToken =
        (await SessionStorage.getToken()) ?? _lastRegisteredSessionToken;
    final pushToken =
        await FirebaseMessaging.instance.getToken() ?? _lastRegisteredPushToken;

    if (authToken == null ||
        authToken.isEmpty ||
        pushToken == null ||
        pushToken.isEmpty) {
      return;
    }

    try {
      await _postAuthenticatedJson('/notifications/devices/unregister', {
        'token': pushToken,
        'platform': _detectPlatform(),
        'appName': _appName,
      }, authToken: authToken);
    } catch (error) {
      if (kDebugMode) {
        print('Push notification unregister failed: $error');
      }
    }
  }

  Future<void> _postAuthenticatedJson(
    String path,
    Map<String, dynamic> body, {
    required String authToken,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}$path'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final message = response.body.isEmpty ? 'Reponse vide' : response.body;
    throw Exception('HTTP ${response.statusCode}: $message');
  }

  Future<bool> _ensureFirebaseReady() async {
    if (_firebaseDisabled) {
      return false;
    }

    if (_firebaseReady) {
      return true;
    }

    _firebaseInitializationFuture ??= _initializeFirebase().whenComplete(() {
      _firebaseInitializationFuture = null;
    });
    return _firebaseInitializationFuture!;
  }

  Future<bool> _initializeFirebase() async {
    if (Firebase.apps.isNotEmpty) {
      _firebaseReady = true;
      return true;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firebaseReady = true;
      return true;
    } catch (error) {
      _firebaseDisabled = true;
      if (kDebugMode) {
        print('Firebase initialization failed: $error');
      }
      return false;
    }
  }

  bool _supportsPushNotifications() {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => true,
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  String _detectPlatform() {
    if (kIsWeb) {
      return 'web';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}
