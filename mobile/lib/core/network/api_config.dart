import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static const _dartDefineApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_dartDefineApiBaseUrl.isNotEmpty) {
      return _dartDefineApiBaseUrl;
    }

    final envApiBaseUrl = dotenv.env['API_BASE_URL']?.trim() ?? '';
    if (envApiBaseUrl.isNotEmpty) {
      return envApiBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:3000/api/v1';
    }

    return 'http://10.0.2.2:3000/api/v1';
  }
}
