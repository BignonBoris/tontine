import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class SessionStorage {
  static const _tokenKey = 'authToken';
  static const _secureTokenKey = 'authToken';
  static const _loggedInKey = 'isLoggedIn';
  static const _pendingGroupInvitationTokenKey = 'pendingGroupInvitationToken';
  static const _deviceIdKey = 'deviceId';
  static final List<Future<void> Function()> _beforeClearHooks = [];
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static void registerBeforeClearHook(Future<void> Function() hook) {
    _beforeClearHooks.add(hook);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await _secureStorage.write(key: _secureTokenKey, value: token);
      await prefs.remove(_tokenKey);
    } catch (_) {
      // Fallback temporaire pour les appareils où le Keystore/Keychain
      // est indisponible, afin de ne pas interrompre la connexion.
      await prefs.setString(_tokenKey, token);
    }
    await prefs.setBool(_loggedInKey, true);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final secureToken = await _secureStorage.read(key: _secureTokenKey);
      if (secureToken != null && secureToken.isNotEmpty) {
        return secureToken;
      }
    } catch (_) {
      // Utiliser la valeur legacy si le stockage sécurisé est indisponible.
    }

    final legacyToken = prefs.getString(_tokenKey);
    if (legacyToken == null || legacyToken.isEmpty) {
      return null;
    }

    try {
      await _secureStorage.write(key: _secureTokenKey, value: legacyToken);
      await prefs.remove(_tokenKey);
    } catch (_) {
      // La migration sera retentée lors d'un prochain accès.
    }
    return legacyToken;
  }

  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  static Future<bool> hasActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_loggedInKey) ?? false;
    final token = await getToken();
    return isLoggedIn && token != null && token.isNotEmpty;
  }

  static Future<void> clear() async {
    for (final hook in List<Future<void> Function()>.from(_beforeClearHooks)) {
      try {
        await hook();
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    try {
      await _secureStorage.delete(key: _secureTokenKey);
    } catch (_) {}
    await prefs.remove(_tokenKey);
    await prefs.setBool(_loggedInKey, false);
  }

  static Future<void> savePendingGroupInvitationToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingGroupInvitationTokenKey, token);
  }

  static Future<String?> getPendingGroupInvitationToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingGroupInvitationTokenKey);
  }

  static Future<void> clearPendingGroupInvitationToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingGroupInvitationTokenKey);
  }
}
