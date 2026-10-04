import 'dart:core';

import 'package:agent/core/network/api_client.dart';
import 'package:agent/features/withdrawals/domain/entities/agent_pending_withdrawal.dart';
import 'package:agent/features/withdrawals/domain/entities/agent_withdrawal_preview.dart';

class AgentWithdrawalService {
  final ApiClient _apiClient;

  AgentWithdrawalService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Mode Référence — rechercher un retrait par sa référence WDR-...
  Future<AgentPendingWithdrawal> searchByReference(String reference) async {
    final normalizedReference = reference.trim().toUpperCase();
    final data = await _apiClient.get(
      '/agent/withdrawals/search?reference=${Uri.encodeQueryComponent(normalizedReference)}',
    ) as Map<dynamic, dynamic>;

    return AgentPendingWithdrawal.fromMap(Map<dynamic, dynamic>.from(data));
  }

  /// Mode Direct — Étape 1 : valider client + montant sans créer de retrait
  Future<AgentWithdrawalPreview> previewDirectWithdrawal({
    required String clientQuery,
    required double amount,
  }) async {
    final data = await _apiClient.post(
      '/agent/withdrawals/preview',
      body: {
        'clientQuery': clientQuery.trim(),
        'amount': amount,
      },
    ) as Map<dynamic, dynamic>;

    return AgentWithdrawalPreview.fromMap(Map<dynamic, dynamic>.from(data));
  }

  /// Mode Direct — Étape 2a : créer le retrait côté client (déclenche envoi OTP)
  Future<AgentPendingWithdrawal> createDirectWithdrawal({
    required String clientId,
    required double amount,
  }) async {
    final data = await _apiClient.post(
      '/agent/withdrawals/create',
      body: {
        'clientId': clientId,
        'amount': amount,
      },
    ) as Map<dynamic, dynamic>;

    return AgentPendingWithdrawal.fromMap(Map<dynamic, dynamic>.from(data));
  }

  /// Mode Direct — Étape 2b : payer le retrait avec le code OTP du client
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
