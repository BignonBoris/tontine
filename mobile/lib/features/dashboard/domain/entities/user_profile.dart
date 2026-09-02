class KycSummary {
  final String status;
  final String level;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime? expiresAt;
  final String? rejectionReason;

  const KycSummary({
    required this.status,
    required this.level,
    this.submittedAt,
    this.reviewedAt,
    this.expiresAt,
    this.rejectionReason,
  });

  factory KycSummary.fromMap(Map<dynamic, dynamic>? map) {
    final value = map ?? const <dynamic, dynamic>{};
    DateTime? parseDate(dynamic raw) => raw == null ? null : DateTime.tryParse('$raw');
    return KycSummary(
      status: value['status'] as String? ?? 'unverified',
      level: value['level'] as String? ?? 'basic',
      submittedAt: parseDate(value['submittedAt']),
      reviewedAt: parseDate(value['reviewedAt']),
      expiresAt: parseDate(value['expiresAt']),
      rejectionReason: value['rejectionReason'] as String?,
    );
  }
}

class UserProfile {
  final String displayName;
  final String phoneNumber;
  final String accountType;
  final DateTime memberSince;
  final DateTime? lastLoginAt;
  final KycSummary kyc;

  const UserProfile({
    required this.displayName,
    required this.phoneNumber,
    required this.accountType,
    required this.memberSince,
    this.lastLoginAt,
    this.kyc = const KycSummary(status: 'unverified', level: 'basic'),
  });

  factory UserProfile.initial({required String phoneNumber}) {
    return UserProfile(
      displayName: "Utilisateur VizioBox",
      phoneNumber: phoneNumber,
      accountType: "Personnel",
      memberSince: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
  }

  factory UserProfile.fromMap(Map<dynamic, dynamic> map) {
    return UserProfile(
      displayName: map['displayName'] as String? ?? "Utilisateur VizioBox",
      phoneNumber: map['phoneNumber'] as String? ?? "",
      accountType: map['accountType'] as String? ?? "Personnel",
      memberSince: DateTime.parse(
        map['memberSince'] as String? ?? DateTime.now().toIso8601String(),
      ),
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.parse(map['lastLoginAt'] as String)
          : null,
      kyc: KycSummary.fromMap(map['kyc'] is Map ? map['kyc'] as Map : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'accountType': accountType,
      'memberSince': memberSince.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'kyc': {
        'status': kyc.status,
        'level': kyc.level,
        'submittedAt': kyc.submittedAt?.toIso8601String(),
        'reviewedAt': kyc.reviewedAt?.toIso8601String(),
        'expiresAt': kyc.expiresAt?.toIso8601String(),
        'rejectionReason': kyc.rejectionReason,
      },
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? phoneNumber,
    String? accountType,
    DateTime? memberSince,
    DateTime? lastLoginAt,
    KycSummary? kyc,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountType: accountType ?? this.accountType,
      memberSince: memberSince ?? this.memberSince,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      kyc: kyc ?? this.kyc,
    );
  }
}
