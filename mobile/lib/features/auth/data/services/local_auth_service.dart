import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/storage/session_storage.dart';
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

  static String normalizePhone(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 8) {
      return digits.substring(digits.length - 8);
    }
    return digits;
  }

  static String formatPhoneForInput(String rawPhone) {
    final digits = normalizePhone(rawPhone);
    if (digits.length != 8) {
      return digits;
    }
    return '${digits.substring(0, 2)} ${digits.substring(2, 4)} ${digits.substring(4, 6)} ${digits.substring(6, 8)}';
  }

  static Future<String?> loadSuggestedPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPhone = prefs.getString(_suggestedPhoneKey);
    if (storedPhone == null || storedPhone.isEmpty) {
      return null;
    }
    return formatPhoneForInput(storedPhone);
  }

  static Future<void> _saveSuggestedPhoneNumber(String rawPhoneNumber) async {
    final normalizedPhone = normalizePhone(rawPhoneNumber);
    if (normalizedPhone.length != 8) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_suggestedPhoneKey, normalizedPhone);
  }

  static Future<LocalAuthResult> requestOtp({
    required String rawPhoneNumber,
    required bool isRegistration,
  }) async {
    try {
      final normalizedPhone = normalizePhone(rawPhoneNumber);
      final data = await _apiClient.post(
        '/auth/request-otp',
        authenticated: false,
        body: {
          'phoneNumber': normalizedPhone,
          'purpose': isRegistration ? 'register' : 'login',
        },
      ) as Map<String, dynamic>;

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
  }) async {
    try {
      final normalizedPhone = normalizePhone(rawPhoneNumber);
      final data = await _apiClient.post(
        '/auth/verify-otp',
        authenticated: false,
        body: {
          'phoneNumber': normalizedPhone,
          'code': otpCode,
        },
      ) as Map<String, dynamic>;

      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const ApiException("Jeton d'authentification manquant.");
      }

      await SessionStorage.saveToken(token);
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
      final data = await _apiClient.post(
        '/auth/resend-otp',
        authenticated: false,
        body: {
          'phoneNumber': normalizedPhone,
          'purpose': isRegistration ? 'register' : 'login',
        },
      ) as Map<String, dynamic>;

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
