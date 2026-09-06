// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReminderAdapter extends TypeAdapter<Reminder> {
  @override
  final int typeId = 6;

  @override
  Reminder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Reminder(
      amount: fields[0] as int,
      unit: fields[1] as ReminderUnit,
    );
  }

  @override
  void write(BinaryWriter writer, Reminder obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.amount)
      ..writeByte(1)
      ..write(obj.unit);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReminderUnitAdapter extends TypeAdapter<ReminderUnit> {
  @override
  final int typeId = 11;

  @override
  ReminderUnit read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ReminderUnit.minute;
      case 1:
        return ReminderUnit.hour;
      case 2:
        return ReminderUnit.day;
      case 3:
        return ReminderUnit.week;
      default:
        return ReminderUnit.minute;
    }
  }

  @override
  void write(BinaryWriter writer, ReminderUnit obj) {
    switch (obj) {
      case ReminderUnit.minute:
        writer.writeByte(0);
        break;
      case ReminderUnit.hour:
        writer.writeByte(1);
        break;
      case ReminderUnit.day:
        writer.writeByte(2);
        break;
      case ReminderUnit.week:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderUnitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
