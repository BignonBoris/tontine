import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_config.dart';
import 'package:mobile/core/services/push_notification_service.dart';
import 'package:mobile/core/storage/session_storage.dart';
import 'package:mobile/core/utils/input_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalAuthResult {
  final bool isSuccess;
  final String message;
  final String? phoneNumber;
  final bool? isRegistration;
  final String? otpCode;

  const LocalAuthResult({
    required this.isSuccess,
    required this.message,
    this.phoneNumber,
    this.isRegistration,
    this.otpCode,
  });
}

class LocalAuthService {
  LocalAuthService._();

  static final ApiClient _apiClient = ApiClient();
  static const _suggestedPhoneKey = 'auth.suggestedPhoneNumber';

  static void _logAuthApiCall(String path) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('[AUTH API] POST ${ApiConfig.baseUrl}$path');
  }

  static void _logAuthApiResponse(String path, dynamic data) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('[AUTH API] $path response => ${jsonEncode(data)}');
  }

  static String normalizePhone(String rawPhone) {
    return AppInputRules.normalizePhone(rawPhone);
  }

  static String formatPhoneForInput(String rawPhone) {
    final digits = normalizePhone(rawPhone);
    if (digits.length != 10) {
      return digits;
    }
    return '${digits.substring(0, 2)} ${digits.substring(2, 4)} ${digits.substring(4, 6)} ${digits.substring(6, 8)} ${digits.substring(8, 10)}';
  }

  static Future<String?> loadSuggestedPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPhone = prefs.getString(_suggestedPhoneKey);
    if (storedPhone == null || storedPhone.isEmpty) {
      return null;
    }
    return formatPhoneForInput(storedPhone);
  }

  static Future<String?> loadSuggestedNormalizedPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPhone = prefs.getString(_suggestedPhoneKey);
    if (storedPhone == null || storedPhone.isEmpty) {
      return null;
    }
    return normalizePhone(storedPhone);
  }

  static Future<void> _saveSuggestedPhoneNumber(String rawPhoneNumber) async {
    final normalizedPhone = normalizePhone(rawPhoneNumber);
    if (normalizedPhone.length != 10) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_suggestedPhoneKey, normalizedPhone);
  }

  static Future<LocalAuthResult> requestOtp({
    required String rawPhoneNumber,
    required bool isRegistration,
    String? pinCode,
  }) async {
    try {
      final normalizedPhone = normalizePhone(rawPhoneNumber);
      _logAuthApiCall('/auth/request-otp');
      final data = await _apiClient.post(
        '/auth/request-otp',
        authenticated: false,
        body: {
          'phoneNumber': normalizedPhone,
          'purpose': isRegistration ? 'register' : 'login',
          if (!isRegistration && pinCode != null && pinCode.trim().isNotEmpty)
            'pinCode': pinCode.trim(),
        },
      ) as Map<String, dynamic>;
      _logAuthApiResponse('/auth/request-otp', data);

      await _saveSuggestedPhoneNumber(normalizedPhone);

      return LocalAuthResult(
        isSuccess: true,
        message: 'Code genere avec succes.',
        phoneNumber: data['phoneNumber'] as String?,
        isRegistration: isRegistration,
        otpCode: data['debugOtpCode'] as String?,
      );
    } on ApiException catch (error) {
      return LocalAuthResult(isSuccess: false, message: error.message);
    }
  }

  static Future<LocalAuthResult> verifyOtp({
    required String rawPhoneNumber,
    required String otpCode,
    String? pinCode,
    String? firstName,
    String? lastName,
    String? birthDate,
  }) async {
    try {
      final normalizedPhone = normalizePhone(rawPhoneNumber);
      _logAuthApiCall('/auth/verify-otp');
      final data = await _apiClient.post(
        '/auth/verify-otp',
        authenticated: false,
        body: {
          'phoneNumber': normalizedPhone,
          'code': otpCode,
          if (pinCode != null && pinCode.trim().isNotEmpty)
            'pinCode': pinCode.trim(),
          if (firstName != null && firstName.trim().isNotEmpty)
            'firstName': firstName.trim(),
          if (lastName != null && lastName.trim().isNotEmpty)
            'lastName': lastName.trim(),
          if (birthDate != null && birthDate.trim().isNotEmpty)
            'birthDate': birthDate.trim(),
        },
      ) as Map<String, dynamic>;
      _logAuthApiResponse('/auth/verify-otp', data);

      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const ApiException("Jeton d'authentification manquant.");
      }

      await SessionStorage.saveToken(token);
      unawaited(
        PushNotificationService.instance.syncCurrentToken(force: true),
      );
      await _saveSuggestedPhoneNumber(normalizedPhone);
      return LocalAuthResult(
        isSuccess: true,
        message: 'Verification reussie.',
        phoneNumber: (data['user'] as Map<String, dynamic>?)?['phoneNumber']
            as String?,
      );
    } on ApiException catch (error) {
      return LocalAuthResult(isSuccess: false, message: error.message);
    }
  }

  static Future<LocalAuthResult> resendOtp({
    required String rawPhoneNumber,
    required bool isRegistration,
  }) async {
    try {
      final normalizedPhone = normalizePhone(rawPhoneNumber);
      _logAuthApiCall('/auth/resend-otp');
      final data = await _apiClient.post(
        '/auth/resend-otp',
        authenticated: false,
        body: {
          'phoneNumber': normalizedPhone,
          'purpose': isRegistration ? 'register' : 'login',
        },
      ) as Map<String, dynamic>;
      _logAuthApiResponse('/auth/resend-otp', data);

      await _saveSuggestedPhoneNumber(normalizedPhone);

      return LocalAuthResult(
        isSuccess: true,
        message: 'Nouveau code genere.',
        phoneNumber: data['phoneNumber'] as String?,
        isRegistration: isRegistration,
        otpCode: data['debugOtpCode'] as String?,
      );
    } on ApiException catch (error) {
      return LocalAuthResult(isSuccess: false, message: error.message);
    }
  }
}
