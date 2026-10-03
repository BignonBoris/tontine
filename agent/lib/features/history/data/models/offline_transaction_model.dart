import 'package:hive/hive.dart';

part 'offline_transaction_model.g.dart';

@HiveType(typeId: 0)
class OfflineTransactionModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type; // 'deposit', 'withdrawal'

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final String clientId;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final String previousHash;

  @HiveField(6)
  final String hash;
  
  @HiveField(7)
  bool isSynced;

  OfflineTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.clientId,
    required this.timestamp,
    required this.previousHash,
    required this.hash,
    this.isSynced = false,
  });
}
