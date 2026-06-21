enum TontineCycleStatus {
  nonConfiguree,
  active,
  enAttenteValidationFin,
  terminee,
  arretee,
}

class TontineCycle {
  final double stakeAmount;
  final double cumulativeAmount;
  final TontineCycleStatus status;
  final DateTime? startedAt;
  final DateTime? expectedEndAt;
  final DateTime? endedAt;

  const TontineCycle({
    required this.stakeAmount,
    required this.cumulativeAmount,
    required this.status,
    this.startedAt,
    this.expectedEndAt,
    this.endedAt,
  });

  double get targetAmount => stakeAmount * 31;
  double get netPayoutAmount => stakeAmount * 30;
  double get commissionAmount => stakeAmount;

  double get progress {
    if (targetAmount <= 0) {
      return 0;
    }
    return (cumulativeAmount / targetAmount).clamp(0.0, 1.0);
  }

  bool get isActive =>
      status == TontineCycleStatus.active ||
      status == TontineCycleStatus.enAttenteValidationFin;

  TontineCycle copyWith({
    double? stakeAmount,
    double? cumulativeAmount,
    TontineCycleStatus? status,
    DateTime? startedAt,
    DateTime? expectedEndAt,
    DateTime? endedAt,
  }) {
    return TontineCycle(
      stakeAmount: stakeAmount ?? this.stakeAmount,
      cumulativeAmount: cumulativeAmount ?? this.cumulativeAmount,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      expectedEndAt: expectedEndAt ?? this.expectedEndAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  factory TontineCycle.fromMap(Map<dynamic, dynamic> map) {
    return TontineCycle(
      stakeAmount: _toDouble(map['stakeAmount']),
      cumulativeAmount: _toDouble(map['cumulativeAmount']),
      status: TontineCycleStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => TontineCycleStatus.active,
      ),
      startedAt: _toNullableDateTime(map['startedAt']),
      expectedEndAt: _toNullableDateTime(map['expectedEndAt']),
      endedAt: _toNullableDateTime(map['endedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stakeAmount': stakeAmount,
      'cumulativeAmount': cumulativeAmount,
      'status': status.name,
      'startedAt': startedAt?.toIso8601String(),
      'expectedEndAt': expectedEndAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
    };
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse('$value');
  }

  static DateTime _toDateTime(dynamic value) {
    return _toNullableDateTime(value) ?? DateTime.now();
  }
}
