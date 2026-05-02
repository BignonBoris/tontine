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
}
