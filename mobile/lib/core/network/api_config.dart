import 'package:flutter/foundation.dart';

class ApiConfig {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_apiBaseUrl.isNotEmpty) {
      return _apiBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:3000/api/v1';
    }

    return 'http://10.0.2.2:3000/api/v1';
  }
}
