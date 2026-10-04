import 'dart:async';

import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/services/push_notification_service.dart';
import 'package:agent/core/storage/session_storage.dart';
import 'package:agent/core/utils/input_rules.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AgentAuthService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  AgentAuthService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<String> _getDeviceId() async {
    String? deviceId = await _secureStorage.read(key: 'device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await _secureStorage.write(key: 'device_id', value: deviceId);
    }
    return deviceId;
  }

  Future<Map<String, dynamic>> login({
    required String phoneNumber,
    required String pin,
  }) async {
    final deviceId = await _getDeviceId();

    final data = await _apiClient.post(
      '/agent/auth/login',
      authenticated: false,
      body: {
        'phoneNumber': AgentInputRules.normalizePhone(phoneNumber),
        'pin': pin,
        'deviceId': deviceId,
      },
    ) as Map<String, dynamic>;

    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException("Jeton d'authentification agent manquant.");
    }

    await SessionStorage.saveToken(token);
    
    // Save timeout config if available
    if (data['security'] != null && data['security']['autoLockTimeoutMinutes'] != null) {
      final timeoutStr = data['security']['autoLockTimeoutMinutes'].toString();
      await _secureStorage.write(key: 'auto_lock_timeout', value: timeoutStr);
    }

    if (data['agent'] != null && data['agent']['maxFloatLimit'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('max_cash_float_limit', (data['agent']['maxFloatLimit'] as num).toDouble());
    }

    // Save credentials securely for biometrics
    await _secureStorage.write(key: 'saved_phone', value: phoneNumber);
    await _secureStorage.write(key: 'saved_pin', value: pin);

    unawaited(PushNotificationService.instance.syncCurrentToken(force: true));
    return data;
  }

  Future<Map<String, String>?> getSavedCredentials() async {
    final phone = await _secureStorage.read(key: 'saved_phone');
    final pin = await _secureStorage.read(key: 'saved_pin');
    if (phone != null && pin != null) {
      return {'phone': phone, 'pin': pin};
    }
    return null;
  }

  Future<int> getAutoLockTimeoutMinutes() async {
    final val = await _secureStorage.read(key: 'auto_lock_timeout');
    if (val != null) {
      return int.tryParse(val) ?? 2;
    }
    return 2;
  }

  Future<void> clearSecureData() async {
    await _secureStorage.delete(key: 'saved_phone');
    await _secureStorage.delete(key: 'saved_pin');
    // We intentionally keep the device_id
  }
}
