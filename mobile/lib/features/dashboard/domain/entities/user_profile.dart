class UserProfile {
  final String displayName;
  final String phoneNumber;
  final String accountType;
  final DateTime memberSince;
  final DateTime? lastLoginAt;

  const UserProfile({
    required this.displayName,
    required this.phoneNumber,
    required this.accountType,
    required this.memberSince,
    this.lastLoginAt,
  });

  factory UserProfile.initial({required String phoneNumber}) {
    return UserProfile(
      displayName: "Utilisateur maTontine",
      phoneNumber: phoneNumber,
      accountType: "Personnel",
      memberSince: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
  }

  factory UserProfile.fromMap(Map<dynamic, dynamic> map) {
    return UserProfile(
      displayName: map['displayName'] as String? ?? "Utilisateur maTontine",
      phoneNumber: map['phoneNumber'] as String? ?? "",
      accountType: map['accountType'] as String? ?? "Personnel",
      memberSince: DateTime.parse(
        map['memberSince'] as String? ?? DateTime.now().toIso8601String(),
      ),
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.parse(map['lastLoginAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'accountType': accountType,
      'memberSince': memberSince.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? phoneNumber,
    String? accountType,
    DateTime? memberSince,
    DateTime? lastLoginAt,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountType: accountType ?? this.accountType,
      memberSince: memberSince ?? this.memberSince,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
