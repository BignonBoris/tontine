import 'package:hive/hive.dart';

part 'kyc_enrollment_model.g.dart';

@HiveType(typeId: 1)
class KycEnrollmentModel extends HiveObject {
  @HiveField(0)
  final String clientId;

  @HiveField(1)
  final String lastName;

  @HiveField(11)
  final String firstName;

  @HiveField(12, defaultValue: 100.0)
  final double stakeAmount;

  @HiveField(2)
  final String phoneNumber;

  @HiveField(3)
  final String? documentType; // cni, passport, residence_permit

  @HiveField(4)
  final String? documentNumber;

  @HiveField(5)
  final String? frontImageFilePath;

  @HiveField(6)
  final String? backImageFilePath;

  @HiveField(7)
  final String? selfieFilePath;

  @HiveField(8)
  final String syncStatus; // pending, synced
  
  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final String pinCode;

  KycEnrollmentModel({
    required this.clientId,
    required this.lastName,
    required this.firstName,
    required this.phoneNumber,
    required this.stakeAmount,
    this.documentType,
    this.documentNumber,
    this.frontImageFilePath,
    this.backImageFilePath,
    this.selfieFilePath,
    this.syncStatus = 'pending',
    required this.createdAt,
    required this.pinCode,
  });

  bool get isLevel1 =>
      documentType != null &&
      documentNumber != null &&
      frontImageFilePath != null &&
      selfieFilePath != null;
}
