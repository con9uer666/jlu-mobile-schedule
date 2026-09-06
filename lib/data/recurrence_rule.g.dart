// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurrence_rule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecurrenceRuleAdapter extends TypeAdapter<RecurrenceRule> {
  @override
  final int typeId = 5;

  @override
  RecurrenceRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecurrenceRule(
      freq: fields[0] as RecurrenceFreq,
      interval: fields[1] as int,
      byWeekday: (fields[2] as List?)?.cast<int>(),
      byMonthDay: (fields[3] as List?)?.cast<int>(),
      until: fields[4] as DateTime?,
      count: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, RecurrenceRule obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.freq)
      ..writeByte(1)
      ..write(obj.interval)
      ..writeByte(2)
      ..write(obj.byWeekday)
      ..writeByte(3)
      ..write(obj.byMonthDay)
      ..writeByte(4)
      ..write(obj.until)
      ..writeByte(5)
      ..write(obj.count);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurrenceRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecurrenceFreqAdapter extends TypeAdapter<RecurrenceFreq> {
  @override
  final int typeId = 10;

  @override
  RecurrenceFreq read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RecurrenceFreq.none;
      case 1:
        return RecurrenceFreq.daily;
      case 2:
        return RecurrenceFreq.weekly;
      case 3:
        return RecurrenceFreq.monthly;
      case 4:
        return RecurrenceFreq.yearly;
      default:
        return RecurrenceFreq.none;
    }
  }

  @override
  void write(BinaryWriter writer, RecurrenceFreq obj) {
    switch (obj) {
      case RecurrenceFreq.none:
        writer.writeByte(0);
        break;
      case RecurrenceFreq.daily:
        writer.writeByte(1);
        break;
      case RecurrenceFreq.weekly:
        writer.writeByte(2);
        break;
      case RecurrenceFreq.monthly:
        writer.writeByte(3);
        break;
      case RecurrenceFreq.yearly:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurrenceFreqAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
