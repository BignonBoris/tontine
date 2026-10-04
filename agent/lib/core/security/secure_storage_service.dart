import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const _encryptionKey = 'hive_encryption_key';

  /// Récupère ou génère une clé de chiffrement AES pour Hive
  static Future<List<int>> getEncryptionKey() async {
    String? keyString = await _storage.read(key: _encryptionKey);
    
    if (keyString == null) {
      final key = Hive.generateSecureKey();
      await _storage.write(key: _encryptionKey, value: base64UrlEncode(key));
      return key;
    }
    
    return base64Url.decode(keyString);
  }

  static Future<void> saveAuthToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  static Future<String?> getAuthToken() async {
    return await _storage.read(key: 'auth_token');
  }
  
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
