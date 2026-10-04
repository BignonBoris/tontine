import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  /// Vérifie si le téléphone dispose d'un capteur biométrique configuré.
  static Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] Vérification indisponible : $e');
      return false;
    }
  }

  /// Lance l'authentification biométrique (ou PIN système en fallback).
  ///
  /// `local_auth ^3.x` : l'option `biometricOnly` n'existe plus ;
  /// le fallback vers le PIN système est géré automatiquement par l'OS.
  static Future<bool> authenticate() async {
    try {
      if (!await isBiometricAvailable()) return false;

      return await _auth.authenticate(
        localizedReason:
            'Veuillez vous authentifier pour accéder à votre espace Agent.',
      );
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] Authentification échouée : $e');
      return false;
    }
  }
}
