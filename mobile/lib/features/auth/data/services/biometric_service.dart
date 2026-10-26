import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class BiometricService {
  BiometricService._();
  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const _biometricEnabledKey = 'biometric_enabled';

  /// La fenêtre système (empreinte / code du téléphone) met l'app en pause
  /// pendant qu'elle est affichée. Ces champs permettent à l'écran principal
  /// de ne pas prendre cette pause pour une sortie de l'app (sinon l'écran de
  /// verrouillage se rouvre en boucle après une authentification réussie).
  static bool _authInProgress = false;
  static DateTime? _authGraceUntil;
  static const _authGracePeriod = Duration(seconds: 2);

  static bool get isAuthenticationInProgress {
    if (_authInProgress) return true;
    final graceUntil = _authGraceUntil;
    return graceUntil != null && DateTime.now().isBefore(graceUntil);
  }
  static const _biometricSavedPinKey = 'biometric_saved_pin';

  static Future<bool> isBiometricAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    _authInProgress = true;
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
    } catch (_) {
      return false;
    } finally {
      _authInProgress = false;
      // L'événement « resumed » peut arriver juste après la fin de l'authentification.
      _authGraceUntil = DateTime.now().add(_authGracePeriod);
    }
  }

  static Future<void> setBiometricEnabled(bool enabled, {String? pinCode}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
    if (enabled && pinCode != null) {
      await _secureStorage.write(key: _biometricSavedPinKey, value: pinCode);
      // Nettoyer l'ancien format SharedPreferences non sécurisé
      await prefs.remove(_biometricSavedPinKey);
    } else {
      await _secureStorage.delete(key: _biometricSavedPinKey);
      await prefs.remove(_biometricSavedPinKey);
    }
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  static Future<String?> getSavedPin() async {
    // 1. Lire depuis le stockage matériel sécurisé (Keychain / Keystore)
    final securePin = await _secureStorage.read(key: _biometricSavedPinKey);
    if (securePin != null && securePin.isNotEmpty) {
      return securePin;
    }

    // 2. Fallback de migration transparente si un ancien PIN Base64 existe dans SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final encodedPin = prefs.getString(_biometricSavedPinKey);
    if (encodedPin != null) {
      try {
        final decoded = utf8.decode(base64Decode(encodedPin));
        // Migrer immédiatement vers le stockage sécurisé et supprimer l'ancien
        await _secureStorage.write(key: _biometricSavedPinKey, value: decoded);
        await prefs.remove(_biometricSavedPinKey);
        return decoded;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
