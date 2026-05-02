// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tontine_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TontineTransactionAdapter extends TypeAdapter<TontineTransaction> {
  @override
  final int typeId = 2;

  @override
  TontineTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TontineTransaction(
      id: fields[0] as String,
      title: fields[1] as String,
      amount: fields[2] as double,
      date: fields[3] as DateTime,
      isDeposit: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TontineTransaction obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.isDeposit);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TontineTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
