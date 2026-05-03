class AgentProvisioning {
  final String id;
  final String reference;
  final double amount;
  final String status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? validatedAt;
  final AgentProvisioningClient? client;

  const AgentProvisioning({
    required this.id,
    required this.reference,
    required this.amount,
    required this.status,
    this.notes,
    this.createdAt,
    this.validatedAt,
    this.client,
  });

  factory AgentProvisioning.fromMap(Map<dynamic, dynamic> map) {
    return AgentProvisioning(
      id: map['id'] as String? ?? '',
      reference: map['reference'] as String? ?? '',
      amount: _toDouble(map['amount']),
      status: map['status'] as String? ?? 'validated',
      notes: map['notes'] as String?,
      createdAt: _toDate(map['createdAt']),
      validatedAt: _toDate(map['validatedAt']),
      client: map['client'] is Map
          ? AgentProvisioningClient.fromMap(map['client'] as Map)
          : null,
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }
}

class AgentProvisioningClient {
  final String id;
  final String displayName;
  final String phoneNumber;

  const AgentProvisioningClient({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
  });

  factory AgentProvisioningClient.fromMap(Map<dynamic, dynamic> map) {
    return AgentProvisioningClient(
      id: map['id'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
    );
  }
}
