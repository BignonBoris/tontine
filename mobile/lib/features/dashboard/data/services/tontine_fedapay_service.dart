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
  // Paiement sans redirection (push USSD)
  final String channel;
  final String? pushOperator;
  final String? pushPhoneMasked;
  final String? lastErrorCode;
  final String? failureMessage;

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
    this.channel = 'redirect',
    this.pushOperator,
    this.pushPhoneMasked,
    this.lastErrorCode,
    this.failureMessage,
  });

  bool get hasPaymentUrl =>
      paymentUrl != null && paymentUrl!.trim().isNotEmpty;

  bool get isSucceeded {
    final normalized = status.toLowerCase();
    return normalized == 'processed' ||
        (providerStatus?.toLowerCase() ?? '') == 'approved';
  }

  bool get isFailed {
    final normalized = status.toLowerCase();
    return normalized == 'failed' ||
        normalized == 'cancelled' ||
        normalized == 'expired';
  }

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
      channel: _toNullableString(map['channel']) ?? 'redirect',
      pushOperator: _toNullableString(map['pushOperator']),
      pushPhoneMasked: _toNullableString(map['pushPhoneMasked']),
      lastErrorCode: _toNullableString(map['lastErrorCode']),
      failureMessage: _toNullableString(map['failureMessage']),
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

  /// Paiement sans redirection : la demande s'affiche sur le telephone du
  /// client, qui valide avec son code secret Mobile Money.
  /// [operator] : 'mtn', 'moov' ou 'celtiis'.
  Future<TontineFedapayDepositIntent> createPushDeposit({
    required double amount,
    required String syncId,
    required String operator,
    required String phoneNumber,
  }) async {
    final payload = await _apiClient.post(
      '/tontine/fedapay/push-deposits',
      body: {
        'amount': amount,
        'syncId': syncId,
        'operator': operator,
        'phoneNumber': phoneNumber,
      },
    );
    return TontineFedapayDepositIntent.fromMap(_asMap(payload));
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
