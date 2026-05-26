import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const _tokenKey = 'authToken';
  static const _loggedInKey = 'isLoggedIn';
  static const _pendingGroupInvitationTokenKey = 'pendingGroupInvitationToken';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setBool(_loggedInKey, true);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<bool> hasActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_loggedInKey) ?? false;
    final token = prefs.getString(_tokenKey);
    return isLoggedIn && token != null && token.isNotEmpty;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
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
