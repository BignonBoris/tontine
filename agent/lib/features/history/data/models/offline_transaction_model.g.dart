// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_transaction_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineTransactionModelAdapter
    extends TypeAdapter<OfflineTransactionModel> {
  @override
  final int typeId = 0;

  @override
  OfflineTransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineTransactionModel(
      id: fields[0] as String,
      type: fields[1] as String,
      amount: fields[2] as double,
      clientId: fields[3] as String,
      timestamp: fields[4] as DateTime,
      previousHash: fields[5] as String,
      hash: fields[6] as String,
      isSynced: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineTransactionModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.clientId)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.previousHash)
      ..writeByte(6)
      ..write(obj.hash)
      ..writeByte(7)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineTransactionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
