import 'package:flutter/material.dart';
import 'package:hive/hive.dart'; // Import indispensable
import 'tontine_transaction.dart';

// Indique à Hive que cette classe est un objet stockable
// typeId: 0 est unique pour cette classe
part 'tontine_goal.g.dart';

@HiveType(typeId: 0)
enum GoalStatus {
  @HiveField(0)
  active,
  @HiveField(1)
  closed,
}

@HiveType(typeId: 1)
class TontineGoal extends HiveObject {
  // Étendre HiveObject permet d'utiliser .save() et .delete()
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final double targetAmount;

  @HiveField(3)
  final double currentAmount;

  @HiveField(4)
  final int iconCodePoint; // Hive ne stocke pas directement IconData

  @HiveField(5)
  final int colorValue; // Hive ne stocke pas directement Color

  @HiveField(6)
  final bool isPriority;

  @HiveField(7)
  final GoalStatus status;

  @HiveField(8)
  final List<TontineTransaction> transactions;

  @HiveField(9)
  final DateTime startDate;

  @HiveField(10)
  final DateTime endDate;

  final String? linkedOfferId;
  final int quantity;
  final double? unitPrice;

  TontineGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.iconCodePoint,
    required this.colorValue,
    this.isPriority = false,
    this.status = GoalStatus.active,
    this.transactions = const [],
    required this.startDate,
    required this.endDate,
    this.linkedOfferId,
    this.quantity = 1,
    this.unitPrice,
  });

  // Getters pour reconstruire les objets Flutter à partir des données Hive
  // Les icônes sont dynamiques (stockées dans Hive), donc le tree-shaking
  // d'icônes doit être désactivé via --no-tree-shake-icons au build.
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  // --- Tes méthodes de calcul restent inchangées ---
  int get remainingDays {
    final difference = endDate.difference(DateTime.now()).inDays;
    return difference > 0 ? difference : 0;
  }

  double get progress {
    if (targetAmount <= 0) return 0.0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  TontineGoal copyWith({
    bool? isPriority,
    GoalStatus? status,
    double? currentAmount,
    List<TontineTransaction>? transactions,
  }) {
    return TontineGoal(
      id: id,
      title: title,
      targetAmount: targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      isPriority: isPriority ?? this.isPriority,
      status: status ?? this.status,
      transactions: transactions ?? this.transactions,
      startDate: startDate,
      endDate: endDate,
      linkedOfferId: linkedOfferId,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }

  factory TontineGoal.fromMap(Map<dynamic, dynamic> map) {
    final transactions = _asList(map['transactions'])
        .map((entry) => TontineTransaction.fromMap(_asMap(entry)))
        .toList();

    return TontineGoal(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      targetAmount: _toDouble(map['targetAmount']),
      currentAmount: _toDouble(map['currentAmount']),
      iconCodePoint: _toInt(map['iconCodePoint']),
      colorValue: _toInt(map['colorValue']),
      isPriority: map['isPriority'] as bool? ?? false,
      status: GoalStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => GoalStatus.active,
      ),
      transactions: transactions,
      startDate: _toDateTime(map['startDate']),
      endDate: _toDateTime(map['endDate']),
      linkedOfferId: map['linkedOfferId']?.toString(),
      quantity: _toInt(map['quantity'], defaultValue: 1)
          .clamp(1, 999999)
          .toInt(),
      unitPrice: map['unitPrice'] == null ? null : _toDouble(map['unitPrice']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'isPriority': isPriority,
      'status': status.name,
      'transactions': transactions.map((transaction) => transaction.toMap()).toList(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'linkedOfferId': linkedOfferId,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  static Map<dynamic, dynamic> _asMap(dynamic raw) {
    if (raw is Map) {
      return Map<dynamic, dynamic>.from(raw);
    }
    return <dynamic, dynamic>{};
  }

  static List<dynamic> _asList(dynamic raw) {
    if (raw is List) {
      return List<dynamic>.from(raw);
    }
    return <dynamic>[];
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  static int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? defaultValue;
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse('$value') ?? DateTime.now();
  }
}
