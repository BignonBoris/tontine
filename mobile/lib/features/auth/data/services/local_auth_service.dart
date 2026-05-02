import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/storage/session_storage.dart';

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

  static String normalizePhone(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 8) {
      return digits.substring(digits.length - 8);
    }
    return digits;
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
