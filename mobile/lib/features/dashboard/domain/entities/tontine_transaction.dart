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
}
