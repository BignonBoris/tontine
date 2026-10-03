import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/storage/session_storage.dart';

class DeviceApprovalService {
  final ApiClient _apiClient;
  DeviceApprovalService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<String> get deviceId => SessionStorage.getOrCreateDeviceId();

  Future<Map<String, dynamic>> status(String requestId) async {
    final id = await deviceId;
    final data = await _apiClient.get(
      '/auth/device-approval/$requestId/status?deviceId=${Uri.encodeQueryComponent(id)}',
      authenticated: false,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<dynamic>> pending() async {
    final data = await _apiClient.get('/auth/device-approval/pending');
    return List<dynamic>.from(data as List);
  }

  Future<void> approve(String requestId) async {
    final id = await deviceId;
    await _apiClient.post('/auth/device-approval/$requestId/approve', body: {'deviceId': id});
  }

  Future<void> reject(String requestId) async {
    final id = await deviceId;
    await _apiClient.post('/auth/device-approval/$requestId/reject', body: {'deviceId': id});
  }
}
