enum TontineArchiveStatus { completed, stoppedEarly }

class TontineArchiveEntry {
  final String id;
  final DateTime startDate;
  final DateTime? expectedEndDate;
  final DateTime endDate;
  final double stakeAmount;
  final double targetAmount;
  final double cumulativeAmount;
  final double commissionAmount;
  final double netPayoutAmount;
  final TontineArchiveStatus status;

  const TontineArchiveEntry({
    required this.id,
    required this.startDate,
    this.expectedEndDate,
    required this.endDate,
    required this.stakeAmount,
    required this.targetAmount,
    required this.cumulativeAmount,
    required this.commissionAmount,
    required this.netPayoutAmount,
    required this.status,
  });

  factory TontineArchiveEntry.fromMap(Map<dynamic, dynamic> map) {
    return TontineArchiveEntry(
      id: map['id'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      expectedEndDate: map['expectedEndDate'] == null
          ? null
          : DateTime.parse(map['expectedEndDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      stakeAmount: _parseDouble(map['stakeAmount']),
      targetAmount: _parseDouble(map['targetAmount']),
      cumulativeAmount: _parseDouble(map['cumulativeAmount']),
      commissionAmount: _parseDouble(map['commissionAmount']),
      netPayoutAmount: _parseDouble(map['netPayoutAmount']),
      status: TontineArchiveStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => TontineArchiveStatus.completed,
      ),
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
      'startDate': startDate.toIso8601String(),
      'expectedEndDate': expectedEndDate?.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'stakeAmount': stakeAmount,
      'targetAmount': targetAmount,
      'cumulativeAmount': cumulativeAmount,
      'commissionAmount': commissionAmount,
      'netPayoutAmount': netPayoutAmount,
      'status': status.name,
    };
  }
}
