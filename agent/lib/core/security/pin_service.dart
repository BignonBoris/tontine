import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service gérant le PIN local de l'agent.
///
/// Responsabilités :
/// - Hachage SHA-256 du PIN (jamais stocké en clair)
/// - Vérification du PIN
/// - Comptage des tentatives échouées
/// - Verrouillage temporaire (30 s après 3 échecs)
/// - Déconnexion forcée (après 5 échecs)
///
/// ⚠️ Le PIN est 100 % local. Il n'est jamais envoyé au serveur.
class PinService {
  static const _storage = FlutterSecureStorage();

  static const _keyPinHash = 'agent_pin_hash';
  static const _keyFailedAttempts = 'pin_failed_attempts';
  static const _keyLockUntil = 'pin_lock_until';

  /// Nombre de tentatives avant verrouillage court (30 s).
  static const int _softLockThreshold = 3;

  /// Nombre de tentatives avant déconnexion forcée.
  static const int _hardLockThreshold = 5;

  /// Durée du verrouillage court.
  static const Duration _softLockDuration = Duration(seconds: 30);

  // ─── Hachage ────────────────────────────────────────────────────────────────

  static String _hash(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  // ─── Configuration ──────────────────────────────────────────────────────────

  /// Enregistre un nouveau PIN (premier setup ou changement).
  static Future<void> setPin(String pin) async {
    await _storage.write(key: _keyPinHash, value: _hash(pin));
    await _resetAttempts();
  }

  /// Retourne `true` si un PIN est configuré.
  static Future<bool> hasPinSet() async {
    final hash = await _storage.read(key: _keyPinHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Supprime le PIN (déconnexion totale).
  static Future<void> clearPin() async {
    await _storage.delete(key: _keyPinHash);
    await _resetAttempts();
  }

  // ─── Vérification ───────────────────────────────────────────────────────────

  /// Vérifie le PIN saisi.
  ///
  /// Retourne un [PinVerificationResult] indiquant le résultat.
  static Future<PinVerificationResult> verifyPin(String pin) async {
    // 1. Vérifier si verrouillé
    final lockStatus = await getLockStatus();
    if (lockStatus.isLocked) {
      return PinVerificationResult.locked(lockStatus.remainingSeconds);
    }

    // 2. Comparer les hashs
    final storedHash = await _storage.read(key: _keyPinHash);
    if (storedHash == null) {
      return PinVerificationResult.noPinSet();
    }

    if (_hash(pin) == storedHash) {
      await _resetAttempts();
      return PinVerificationResult.success();
    }

    // 3. Enregistrer l'échec
    final attempts = await _incrementFailedAttempts();
    debugPrint('[PinService] Tentative échouée n°$attempts');

    if (attempts >= _hardLockThreshold) {
      // Déconnexion forcée
      return PinVerificationResult.forceLogout();
    }

    if (attempts >= _softLockThreshold) {
      // Verrouillage 30 s
      final lockUntil = DateTime.now().add(_softLockDuration);
      await _storage.write(
        key: _keyLockUntil,
        value: lockUntil.millisecondsSinceEpoch.toString(),
      );
      return PinVerificationResult.locked(_softLockDuration.inSeconds);
    }

    final remaining = _hardLockThreshold - attempts;
    return PinVerificationResult.wrongPin(attempts, remaining);
  }

  // ─── Statut du verrou ────────────────────────────────────────────────────────

  /// Retourne le statut actuel du verrou (verrouillé ou libre).
  static Future<LockStatus> getLockStatus() async {
    final lockUntilStr = await _storage.read(key: _keyLockUntil);
    if (lockUntilStr == null) return LockStatus.unlocked();

    final lockUntilMs = int.tryParse(lockUntilStr);
    if (lockUntilMs == null) return LockStatus.unlocked();

    final lockUntil = DateTime.fromMillisecondsSinceEpoch(lockUntilMs);
    final now = DateTime.now();

    if (now.isBefore(lockUntil)) {
      final remaining = lockUntil.difference(now).inSeconds;
      return LockStatus.locked(remaining);
    }

    // Verrou expiré → nettoyage
    await _storage.delete(key: _keyLockUntil);
    return LockStatus.unlocked();
  }

  // ─── Helpers privés ──────────────────────────────────────────────────────────

  static Future<int> _incrementFailedAttempts() async {
    final val = await _storage.read(key: _keyFailedAttempts);
    final current = int.tryParse(val ?? '0') ?? 0;
    final next = current + 1;
    await _storage.write(key: _keyFailedAttempts, value: next.toString());
    return next;
  }

  static Future<void> _resetAttempts() async {
    await _storage.delete(key: _keyFailedAttempts);
    await _storage.delete(key: _keyLockUntil);
  }

  static Future<int> getFailedAttempts() async {
    final val = await _storage.read(key: _keyFailedAttempts);
    return int.tryParse(val ?? '0') ?? 0;
  }
}

// ─── Value Objects ─────────────────────────────────────────────────────────────

enum PinVerificationStatus {
  success,
  wrongPin,
  locked,
  forceLogout,
  noPinSet,
}

class PinVerificationResult {
  final PinVerificationStatus status;
  final int failedAttempts;
  final int remainingAttempts;
  final int remainingLockSeconds;

  const PinVerificationResult._({
    required this.status,
    this.failedAttempts = 0,
    this.remainingAttempts = 0,
    this.remainingLockSeconds = 0,
  });

  factory PinVerificationResult.success() =>
      const PinVerificationResult._(status: PinVerificationStatus.success);

  factory PinVerificationResult.wrongPin(int failed, int remaining) =>
      PinVerificationResult._(
        status: PinVerificationStatus.wrongPin,
        failedAttempts: failed,
        remainingAttempts: remaining,
      );

  factory PinVerificationResult.locked(int remainingSeconds) =>
      PinVerificationResult._(
        status: PinVerificationStatus.locked,
        remainingLockSeconds: remainingSeconds,
      );

  factory PinVerificationResult.forceLogout() =>
      const PinVerificationResult._(status: PinVerificationStatus.forceLogout);

  factory PinVerificationResult.noPinSet() =>
      const PinVerificationResult._(status: PinVerificationStatus.noPinSet);
}

class LockStatus {
  final bool isLocked;
  final int remainingSeconds;

  const LockStatus._({required this.isLocked, this.remainingSeconds = 0});

  factory LockStatus.unlocked() => const LockStatus._(isLocked: false);
  factory LockStatus.locked(int remainingSeconds) =>
      LockStatus._(isLocked: true, remainingSeconds: remainingSeconds);
}
