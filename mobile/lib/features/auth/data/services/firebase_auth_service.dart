import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/services/push_notification_service.dart';
import 'package:mobile/core/storage/session_storage.dart';
import 'package:mobile/features/auth/data/services/local_auth_service.dart';

class SimDetectionResult {
  final String? phoneNumber;
  final bool isSimCertified;
  final String? certifiedIdToken;

  const SimDetectionResult({
    this.phoneNumber,
    this.isSimCertified = false,
    this.certifiedIdToken,
  });
}

class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ApiClient _apiClient = ApiClient();

  /// Tente de détecter automatiquement le numéro SIM certifié au chargement.
  /// En environnement mobile avec SIM active, vérifie si un jeton FPNV est disponible.
  Future<SimDetectionResult> detectSimPhoneNumber() async {
    try {
      // 1. Vérifier si un numéro certifié récent ou suggéré existe
      final suggestedPhone = await LocalAuthService.loadSuggestedNormalizedPhoneNumber();
      
      // 2. Vérifier si l'utilisateur courant Firebase possède déjà une session active
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.phoneNumber != null) {
        final idToken = await currentUser.getIdToken();
        return SimDetectionResult(
          phoneNumber: currentUser.phoneNumber,
          isSimCertified: true,
          certifiedIdToken: idToken,
        );
      }

      if (suggestedPhone != null && suggestedPhone.isNotEmpty) {
        return SimDetectionResult(
          phoneNumber: suggestedPhone,
          isSimCertified: false,
        );
      }

      return const SimDetectionResult();
    } catch (e) {
      debugPrint('[FPNV] Détection SIM non disponible : $e');
      return const SimDetectionResult();
    }
  }

  /// Vérifie le jeton Firebase (FPNV ou SMS OTP) auprès du backend VizioBox.
  Future<LocalAuthResult> verifyFirebaseTokenOnBackend({
    required String idToken,
    String? pinCode,
    String? firstName,
    String? lastName,
    String? birthDate,
    String? purpose,
  }) async {
    try {
      final deviceId = await SessionStorage.getOrCreateDeviceId();
      final response = await _apiClient.post(
        '/auth/firebase-verify',
        authenticated: false,
        body: {
          'idToken': idToken,
          'deviceId': deviceId,
          if (pinCode != null && pinCode.trim().isNotEmpty)
            'pinCode': pinCode.trim(),
          if (firstName != null && firstName.trim().isNotEmpty)
            'firstName': firstName.trim(),
          if (lastName != null && lastName.trim().isNotEmpty)
            'lastName': lastName.trim(),
          if (birthDate != null && birthDate.trim().isNotEmpty)
            'birthDate': birthDate.trim(),
          // ignore: use_null_aware_elements
          if (purpose != null) 'purpose': purpose,
        },
      ) as Map<String, dynamic>;

      if (response['requiresDeviceApproval'] == true) {
        return LocalAuthResult(
          isSuccess: false,
          message: 'Une autorisation est requise sur votre appareil déjà connecté.',
          requiresDeviceApproval: true,
          approvalRequestId: response['approvalRequestId'] as String?,
        );
      }

      final token = response['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const ApiException("Jeton d'authentification manquant dans la réponse.");
      }

      await SessionStorage.saveToken(token);
      unawaited(PushNotificationService.instance.syncCurrentToken(force: true));

      final userData = response['user'] as Map<String, dynamic>?;
      final phone = userData?['phoneNumber'] as String?;
      if (phone != null) {
        final normalized = LocalAuthService.normalizePhone(phone);
        await LocalAuthService.saveSuggestedPhoneNumber(normalized);
      }

      return LocalAuthResult(
        isSuccess: true,
        message: 'Authentification certifiée avec succès.',
        phoneNumber: phone,
      );
    } on ApiException catch (error) {
      return LocalAuthResult(isSuccess: false, message: error.message);
    } catch (error) {
      return LocalAuthResult(isSuccess: false, message: error.toString());
    }
  }

  /// Normalise le numéro au format international E.164 (+229XXXXXXXX)
  static String formatToE164(String phoneNumber) {
    final trimmed = phoneNumber.trim();
    if (trimmed.startsWith('+')) {
      final digits = trimmed.replaceAll(RegExp(r'\D'), '');
      return '+$digits';
    }
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('229')) {
      return '+$digits';
    }
    return '+229$digits';
  }

  /// Déclenche l'envoi du code SMS OTP via Firebase Auth (mode Fallback).
  Future<void> sendFirebaseSmsOtp({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String errorMessage) onError,
    required Function(String idToken) onAutoVerified,
    int? resendToken,
  }) async {
    try {
      final formattedPhone = formatToE164(phoneNumber);
      debugPrint('[Firebase Auth] Démarrage vérification pour $formattedPhone');

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval réussi sur Android sans saisie
          try {
            debugPrint('[Firebase Auth] Auto-vérification réussie par Google Play Services');
            final userCredential = await _auth.signInWithCredential(credential);
            final idToken = await userCredential.user?.getIdToken();
            if (idToken != null) {
              onAutoVerified(idToken);
            }
          } catch (e) {
            onError('Échec de la validation automatique du SMS : $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('[Firebase Auth] Erreur SMS OTP : ${e.code} - ${e.message}');
          String message = 'Erreur lors de l\'envoi du code SMS.';
          if (e.code == 'invalid-phone-number') {
            message = 'Le numéro de téléphone est invalide.';
          } else if (e.code == 'too-many-requests') {
            message = 'Trop de tentatives SMS. Veuillez patienter avant de réessayer.';
          } else if (e.code == 'quota-exceeded') {
            message = 'Quota SMS temporairement atteint.';
          } else if (e.message != null && e.message!.isNotEmpty) {
            message = e.message!;
          }
          onError(message);
        },
        codeSent: (String verificationId, int? newResendToken) {
          debugPrint('[Firebase Auth] Code SMS expédié. ID: $verificationId');
          onCodeSent(verificationId, newResendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('[Firebase Auth] Timeout auto-retrieval pour $verificationId');
        },
      );
    } catch (e) {
      debugPrint('[Firebase Auth] Exception inattendue : $e');
      onError('Erreur imprévue lors de la demande SMS : $e');
    }
  }

  /// Valide le code SMS saisi par l'utilisateur et finalise la session.
  Future<LocalAuthResult> confirmSmsOtp({
    required String verificationId,
    required String smsCode,
    String? pinCode,
    String? firstName,
    String? lastName,
    String? birthDate,
    String? purpose,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();

      if (idToken == null || idToken.isEmpty) {
        return const LocalAuthResult(
          isSuccess: false,
          message: "Impossible d'obtenir le jeton de sécurité.",
        );
      }

      return await verifyFirebaseTokenOnBackend(
        idToken: idToken,
        pinCode: pinCode,
        firstName: firstName,
        lastName: lastName,
        birthDate: birthDate,
        purpose: purpose,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Code de sécurité invalide.';
      if (e.code == 'invalid-verification-code') {
        message = 'Le code SMS saisi est incorrect.';
      } else if (e.code == 'session-expired') {
        message = 'Le code SMS a expiré. Veuillez en demander un nouveau.';
      }
      return LocalAuthResult(isSuccess: false, message: message);
    } catch (e) {
      return LocalAuthResult(isSuccess: false, message: e.toString());
    }
  }
}
