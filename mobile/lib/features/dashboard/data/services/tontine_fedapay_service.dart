import 'package:mobile/core/network/api_client.dart';

class TontineFedapayDepositIntent {
  final String id;
  final double amount;
  final String status;
  final String merchantReference;
  final String? providerTransactionId;
  final String? providerStatus;
  final String? paymentUrl;
  final String? callbackUrl;
  final String? failureReason;

  const TontineFedapayDepositIntent({
    required this.id,
    required this.amount,
    required this.status,
    required this.merchantReference,
    this.providerTransactionId,
    this.providerStatus,
    this.paymentUrl,
    this.callbackUrl,
    this.failureReason,
  });

  bool get hasPaymentUrl =>
      paymentUrl != null && paymentUrl!.trim().isNotEmpty;

  factory TontineFedapayDepositIntent.fromMap(Map<dynamic, dynamic> map) {
    return TontineFedapayDepositIntent(
      id: '${map['id'] ?? ''}',
      amount: _toDouble(map['amount']),
      status: '${map['status'] ?? ''}',
      merchantReference: '${map['merchantReference'] ?? ''}',
      providerTransactionId: _toNullableString(map['providerTransactionId']),
      providerStatus: _toNullableString(map['providerStatus']),
      paymentUrl: _toNullableString(map['paymentUrl']),
      callbackUrl: _toNullableString(map['callbackUrl']),
      failureReason: _toNullableString(map['failureReason']),
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
}

class TontineFedapayService {
  final ApiClient _apiClient;

  TontineFedapayService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<TontineFedapayDepositIntent> createDeposit(double amount, String syncId) async {
    final payload = await _apiClient.post(
      '/tontine/fedapay/deposits',
      body: {'amount': amount, 'syncId': syncId},
    );
    final intent = TontineFedapayDepositIntent.fromMap(_asMap(payload));
    if (!intent.hasPaymentUrl) {
      throw const ApiException(
        'Le lien FedaPay est indisponible pour ce paiement.',
        null,
        ApiErrorType.server,
      );
    }
    return intent;
  }

  Future<TontineFedapayDepositIntent> fetchDepositIntent(
    String intentId,
  ) async {
    final payload = await _apiClient.get('/tontine/fedapay/deposits/$intentId');
    return TontineFedapayDepositIntent.fromMap(_asMap(payload));
  }

  static Map<dynamic, dynamic> _asMap(dynamic raw) {
    if (raw is Map) {
      return Map<dynamic, dynamic>.from(raw);
    }
    return <dynamic, dynamic>{};
  }
}
