import 'dart:core';

import 'package:agent/core/network/api_client.dart';
import 'package:agent/features/withdrawals/domain/entities/agent_pending_withdrawal.dart';

class AgentWithdrawalService {
  final ApiClient _apiClient;

  AgentWithdrawalService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<AgentPendingWithdrawal> searchByReference(String reference) async {
    final normalizedReference = reference.trim().toUpperCase();
    final data = await _apiClient.get(
      '/agent/withdrawals/search?reference=${Uri.encodeQueryComponent(normalizedReference)}',
    ) as Map<dynamic, dynamic>;

    return AgentPendingWithdrawal.fromMap(Map<dynamic, dynamic>.from(data));
  }

  Future<Map<String, dynamic>> payWithdrawal({
    required String withdrawalId,
    required String confirmationCode,
  }) async {
    final data = await _apiClient.post(
      '/agent/withdrawals/$withdrawalId/pay',
      body: {
        'confirmationCode': confirmationCode.trim(),
      },
    ) as Map<dynamic, dynamic>;

    return Map<String, dynamic>.from(data);
  }
}
