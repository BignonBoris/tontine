import 'package:mobile/core/network/api_client.dart';

class TontineMtnMomoDepositIntent {
  final String id;
  final String userId;
  final String cycleId;
  final double amount;
  final String provider;
  final String merchantReference;
  final String? providerTransactionId;
  final String? paymentUrl;
  final String? callbackUrl;
  final String status;
  final String? providerStatus;
  final String? failureReason;
  final String? depositHistoryId;
  final DateTime? approvedAt;
  final DateTime? processedAt;
  final DateTime? failedAt;
  final DateTime? cancelledAt;
  final DateTime? expiredAt;

  const TontineMtnMomoDepositIntent({
    required this.id,
    required this.userId,
    required this.cycleId,
    required this.amount,
    required this.provider,
    required this.merchantReference,
    this.providerTransactionId,
    this.paymentUrl,
    this.callbackUrl,
    required this.status,
    this.providerStatus,
    this.failureReason,
    this.depositHistoryId,
    this.approvedAt,
    this.processedAt,
    this.failedAt,
    this.cancelledAt,
    this.expiredAt,
  });

  bool get hasPaymentUrl =>
      paymentUrl != null && paymentUrl!.trim().isNotEmpty;

  factory TontineMtnMomoDepositIntent.fromMap(Map<dynamic, dynamic> map) {
    return TontineMtnMomoDepositIntent(
      id: '${map['id'] ?? ''}',
      userId: '${map['userId'] ?? ''}',
      cycleId: '${map['cycleId'] ?? ''}',
      amount: _toDouble(map['amount']),
      provider: '${map['provider'] ?? 'mtn_momo'}',
      merchantReference: '${map['merchantReference'] ?? ''}',
      providerTransactionId: _toNullableString(map['providerTransactionId']),
      paymentUrl: _toNullableString(map['paymentUrl']),
      callbackUrl: _toNullableString(map['callbackUrl']),
      status: '${map['status'] ?? ''}',
      providerStatus: _toNullableString(map['providerStatus']),
      failureReason: _toNullableString(map['failureReason']),
      depositHistoryId: _toNullableString(map['depositHistoryId']),
      approvedAt: _toNullableDateTime(map['approvedAt']),
      processedAt: _toNullableDateTime(map['processedAt']),
      failedAt: _toNullableDateTime(map['failedAt']),
      cancelledAt: _toNullableDateTime(map['cancelledAt']),
      expiredAt: _toNullableDateTime(map['expiredAt']),
    );
  }

  static String? _toNullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    final parsed = DateTime.tryParse('${value ?? ''}');
    return parsed;
  }
}

class TontineMtnMomoService {
  final ApiClient _apiClient;

  TontineMtnMomoService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<TontineMtnMomoDepositIntent> createDeposit(double amount) async {
    final payload = await _apiClient.post(
      '/tontine/mtn-momo/deposits',
      body: {'amount': amount},
    );
    return TontineMtnMomoDepositIntent.fromMap(_asMap(payload));
  }

  Future<TontineMtnMomoDepositIntent> fetchDepositIntent(
    String intentId,
  ) async {
    final payload = await _apiClient.get('/tontine/mtn-momo/deposits/$intentId');
    return TontineMtnMomoDepositIntent.fromMap(_asMap(payload));
  }

  static Map<dynamic, dynamic> _asMap(dynamic raw) {
    if (raw is Map) {
      return Map<dynamic, dynamic>.from(raw);
    }
    return <dynamic, dynamic>{};
  }
}
