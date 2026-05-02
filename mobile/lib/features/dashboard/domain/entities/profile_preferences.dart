class ProfilePreferences {
  final bool depositNotificationsEnabled;
  final bool cycleNotificationsEnabled;
  final bool marketingNotificationsEnabled;
  final bool pinEnabled;
  final bool biometricEnabled;
  final String? pinCode;

  const ProfilePreferences({
    required this.depositNotificationsEnabled,
    required this.cycleNotificationsEnabled,
    required this.marketingNotificationsEnabled,
    required this.pinEnabled,
    required this.biometricEnabled,
    this.pinCode,
  });

  const ProfilePreferences.defaults()
    : depositNotificationsEnabled = true,
      cycleNotificationsEnabled = true,
      marketingNotificationsEnabled = false,
      pinEnabled = false,
      biometricEnabled = false,
      pinCode = null;

  factory ProfilePreferences.fromMap(Map<dynamic, dynamic> map) {
    return ProfilePreferences(
      depositNotificationsEnabled:
          map['depositNotificationsEnabled'] as bool? ?? true,
      cycleNotificationsEnabled:
          map['cycleNotificationsEnabled'] as bool? ?? true,
      marketingNotificationsEnabled:
          map['marketingNotificationsEnabled'] as bool? ?? false,
      pinEnabled: map['pinEnabled'] as bool? ?? false,
      biometricEnabled: map['biometricEnabled'] as bool? ?? false,
      pinCode: map['pinCode'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'depositNotificationsEnabled': depositNotificationsEnabled,
      'cycleNotificationsEnabled': cycleNotificationsEnabled,
      'marketingNotificationsEnabled': marketingNotificationsEnabled,
      'pinEnabled': pinEnabled,
      'biometricEnabled': biometricEnabled,
    };
  }

  ProfilePreferences copyWith({
    bool? depositNotificationsEnabled,
    bool? cycleNotificationsEnabled,
    bool? marketingNotificationsEnabled,
    bool? pinEnabled,
    bool? biometricEnabled,
    String? pinCode,
    bool clearPinCode = false,
  }) {
    return ProfilePreferences(
      depositNotificationsEnabled:
          depositNotificationsEnabled ?? this.depositNotificationsEnabled,
      cycleNotificationsEnabled:
          cycleNotificationsEnabled ?? this.cycleNotificationsEnabled,
      marketingNotificationsEnabled:
          marketingNotificationsEnabled ?? this.marketingNotificationsEnabled,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      pinCode: clearPinCode ? null : (pinCode ?? this.pinCode),
    );
  }
}
