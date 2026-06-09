import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static const _definedApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_definedApiBaseUrl.isNotEmpty) {
      return _definedApiBaseUrl;
    }

    final envBaseUrl = dotenv.env['API_BASE_URL']?.trim() ?? '';
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }

    if (kIsWeb) {
      return "https://finance-tontine-api.onrender.com/api/v1";
      // return 'http://localhost:3000/api/v1';
    }

    return "https://finance-tontine-api.onrender.com/api/v1";
    // return 'http://10.0.2.2:3000/api/v1';
  }
}
