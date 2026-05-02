enum MarketOrderStatus { pending, confirmed, ready, completed, cancelled }

class MarketOrder {
  final String id;
  final String offerId;
  final String title;
  final double amount;
  final int quantity;
  final double unitPrice;
  final DateTime date;
  final MarketOrderStatus status;
  final DateTime? updatedAt;

  const MarketOrder({
    required this.id,
    required this.offerId,
    required this.title,
    required this.amount,
    this.quantity = 1,
    this.unitPrice = 0,
    required this.date,
    required this.status,
    this.updatedAt,
  });

  factory MarketOrder.fromMap(Map<dynamic, dynamic> map) {
    return MarketOrder(
      id: map['id'] as String,
      offerId: map['offerId'] as String,
      title: map['title'] as String,
      amount: _parseDouble(map['amount']),
      quantity: _parseInt(map['quantity'], defaultValue: 1),
      unitPrice: _parseDouble(map['unitPrice']),
      date: DateTime.parse(map['date'] as String),
      status: MarketOrderStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => MarketOrderStatus.pending,
      ),
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.tryParse(map['updatedAt'] as String),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'offerId': offerId,
      'title': title,
      'amount': amount,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'date': date.toIso8601String(),
      'status': status.name,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  MarketOrder copyWith({
    String? id,
    String? offerId,
    String? title,
    double? amount,
    int? quantity,
    double? unitPrice,
    DateTime? date,
    MarketOrderStatus? status,
    DateTime? updatedAt,
  }) {
    return MarketOrder(
      id: id ?? this.id,
      offerId: offerId ?? this.offerId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      date: date ?? this.date,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

extension MarketOrderStatusX on MarketOrderStatus {
  String get label {
    switch (this) {
      case MarketOrderStatus.pending:
        return 'En attente';
      case MarketOrderStatus.confirmed:
        return 'Confirmee';
      case MarketOrderStatus.ready:
        return 'Prete';
      case MarketOrderStatus.completed:
        return 'Livree';
      case MarketOrderStatus.cancelled:
        return 'Annulee';
    }
  }

  bool get canAdvance =>
      this == MarketOrderStatus.pending ||
      this == MarketOrderStatus.confirmed ||
      this == MarketOrderStatus.ready;

  bool get canCancel =>
      this == MarketOrderStatus.pending || this == MarketOrderStatus.confirmed;

  MarketOrderStatus get next {
    switch (this) {
      case MarketOrderStatus.pending:
        return MarketOrderStatus.confirmed;
      case MarketOrderStatus.confirmed:
        return MarketOrderStatus.ready;
      case MarketOrderStatus.ready:
        return MarketOrderStatus.completed;
      case MarketOrderStatus.completed:
      case MarketOrderStatus.cancelled:
        return this;
    }
  }

  String get nextActionLabel {
    switch (this) {
      case MarketOrderStatus.pending:
        return 'Confirmer la commande';
      case MarketOrderStatus.confirmed:
        return 'Marquer comme prete';
      case MarketOrderStatus.ready:
        return 'Marquer comme livree';
      case MarketOrderStatus.completed:
      case MarketOrderStatus.cancelled:
        return '';
    }
  }
}
