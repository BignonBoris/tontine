enum TontineHistoryType {
  configuration,
  deposit,
  cycleCompleted,
  payoutConfirmed,
  earlyStop,
  restarted,
}

class TontineHistoryEntry {
  final String id;
  final TontineHistoryType type;
  final double amount;
  final DateTime date;
  final String label;
  final String? note;

  const TontineHistoryEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.label,
    this.note,
  });

  factory TontineHistoryEntry.fromMap(Map<dynamic, dynamic> map) {
    return TontineHistoryEntry(
      id: map['id'] as String,
      type: TontineHistoryType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => TontineHistoryType.deposit,
      ),
      amount: _parseDouble(map['amount']),
      date: DateTime.parse(map['date'] as String),
      label: map['label'] as String,
      note: map['note'] as String?,
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
      'note': note,
    };
  }
}
