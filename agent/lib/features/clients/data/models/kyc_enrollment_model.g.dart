// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kyc_enrollment_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class KycEnrollmentModelAdapter extends TypeAdapter<KycEnrollmentModel> {
  @override
  final int typeId = 1;

  @override
  KycEnrollmentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return KycEnrollmentModel(
      clientId: fields[0] as String,
      lastName: fields[1] as String,
      firstName: fields[11] as String,
      phoneNumber: fields[2] as String,
      stakeAmount: fields[12] == null ? 100.0 : fields[12] as double,
      documentType: fields[3] as String?,
      documentNumber: fields[4] as String?,
      frontImageFilePath: fields[5] as String?,
      backImageFilePath: fields[6] as String?,
      selfieFilePath: fields[7] as String?,
      syncStatus: fields[8] as String,
      createdAt: fields[9] as DateTime,
      pinCode: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, KycEnrollmentModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.clientId)
      ..writeByte(1)
      ..write(obj.lastName)
      ..writeByte(11)
      ..write(obj.firstName)
      ..writeByte(12)
      ..write(obj.stakeAmount)
      ..writeByte(2)
      ..write(obj.phoneNumber)
      ..writeByte(3)
      ..write(obj.documentType)
      ..writeByte(4)
      ..write(obj.documentNumber)
      ..writeByte(5)
      ..write(obj.frontImageFilePath)
      ..writeByte(6)
      ..write(obj.backImageFilePath)
      ..writeByte(7)
      ..write(obj.selfieFilePath)
      ..writeByte(8)
      ..write(obj.syncStatus)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.pinCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KycEnrollmentModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
