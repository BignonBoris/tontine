enum AvailableBalanceHistoryType {
  tontinePayout,
  tontineEarlyStop,
  goalFunding,
  tontineFunding,
  withdrawalRequested,
  withdrawalCancelled,
}

class AvailableBalanceHistoryEntry {
  final String id;
  final AvailableBalanceHistoryType type;
  final double amount;
  final DateTime date;
  final String label;
  final bool isCredit;

  const AvailableBalanceHistoryEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.label,
    required this.isCredit,
  });

  factory AvailableBalanceHistoryEntry.fromMap(Map<dynamic, dynamic> map) {
    return AvailableBalanceHistoryEntry(
      id: map['id'] as String,
      type: AvailableBalanceHistoryType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => AvailableBalanceHistoryType.goalFunding,
      ),
      amount: _parseDouble(map['amount']),
      date: DateTime.parse(map['date'] as String),
      label: map['label'] as String,
      isCredit: map['isCredit'] as bool,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'date': date.toIso8601String(),
      'label': label,
      'isCredit': isCredit,
    };
  }
}
