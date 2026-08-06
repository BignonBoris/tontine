class PaymentMethodOption {
  final String id;
  final String code;
  final String label;
  final String? description;
  final String provider;
  final String operation;
  final String flowType;
  final bool enabled;
  final int sortOrder;

  const PaymentMethodOption({
    required this.id,
    required this.code,
    required this.label,
    this.description,
    required this.provider,
    required this.operation,
    required this.flowType,
    required this.enabled,
    required this.sortOrder,
  });

  factory PaymentMethodOption.fromMap(Map<dynamic, dynamic> map) {
    return PaymentMethodOption(
      id: map['id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      description: map['description']?.toString(),
      provider: map['provider']?.toString() ?? 'internal',
      operation: map['operation']?.toString() ?? '',
      flowType: map['flowType']?.toString() ?? 'internal_transfer',
      enabled: map['enabled'] as bool? ?? true,
      sortOrder: _toInt(map['sortOrder']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }
}
