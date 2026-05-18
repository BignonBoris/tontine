import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/storage/session_storage.dart';
import 'package:agent/core/utils/input_rules.dart';

class AgentAuthService {
  final ApiClient _apiClient;

  AgentAuthService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> login({
    required String phoneNumber,
    required String pin,
  }) async {
    final data = await _apiClient.post(
      '/agent/auth/login',
      authenticated: false,
      body: {
        'phoneNumber': AgentInputRules.normalizePhone(phoneNumber),
        'pin': pin,
      },
    ) as Map<String, dynamic>;

    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException("Jeton d'authentification agent manquant.");
    }

    await SessionStorage.saveToken(token);
    return data;
  }
}
