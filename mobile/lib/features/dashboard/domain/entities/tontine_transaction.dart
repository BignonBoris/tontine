import 'package:hive/hive.dart';

// Ce fichier sera généré par build_runner
part 'tontine_transaction.g.dart';

@HiveType(typeId: 2)
class TontineTransaction extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final bool isDeposit;

  TontineTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.isDeposit,
  });

  factory TontineTransaction.fromMap(Map<dynamic, dynamic> map) {
    return TontineTransaction(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      amount: _toDouble(map['amount']),
      date: _toDateTime(map['date']),
      isDeposit: map['isDeposit'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'isDeposit': isDeposit,
    };
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse('$value') ?? DateTime.now();
  }
}
