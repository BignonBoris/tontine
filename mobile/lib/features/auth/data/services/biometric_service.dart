import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class BiometricService {
  BiometricService._();
  static final LocalAuthentication _auth = LocalAuthentication();

  static const _biometricEnabledKey = 'biometric_enabled';
  static const _biometricSavedPinKey = 'biometric_saved_pin';

  static Future<bool> isBiometricAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason:
            'Veuillez vous authentifier pour accéder à votre compte.',
        biometricOnly: false, // fallback to device credentials
        sensitiveTransaction: true,
      );
      return authenticated;
    } on PlatformException catch (e) {
      if (e.code == 'NotEnrolled') {
        // Biometrics not enrolled
      } else if (e.code == 'LockedOut' ||
          e.code == 'PermanentlyLockedOut') {
        // Locked out
      }
      return false;
    }
  }

  static Future<void> setBiometricEnabled(bool enabled, {String? pinCode}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
    if (enabled && pinCode != null) {
      // In a real app, you'd encrypt this PIN before saving it.
      // For this demo, we'll store it as is (Base64 encoded) so it's not plain text, 
      // but ideally use flutter_secure_storage.
      final encodedPin = base64Encode(utf8.encode(pinCode));
      await prefs.setString(_biometricSavedPinKey, encodedPin);
    } else {
      await prefs.remove(_biometricSavedPinKey);
    }
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  static Future<String?> getSavedPin() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedPin = prefs.getString(_biometricSavedPinKey);
    if (encodedPin != null) {
      try {
        return utf8.decode(base64Decode(encodedPin));
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
