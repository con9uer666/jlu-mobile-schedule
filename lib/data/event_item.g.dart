// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EventItemAdapter extends TypeAdapter<EventItem> {
  @override
  final int typeId = 4;

  @override
  EventItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EventItem(
      id: fields[0] as String,
      title: fields[1] as String,
      note: fields[2] as String?,
      location: fields[3] as String?,
      allDay: fields[4] as bool,
      startAt: fields[5] as DateTime,
      endAt: fields[6] as DateTime,
      recurrence: fields[7] as RecurrenceRule?,
      reminders: (fields[8] as List?)?.cast<Reminder>(),
      colorIndex: fields[9] as int,
      createdAt: fields[10] as DateTime?,
      updatedAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, EventItem obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.note)
      ..writeByte(3)
      ..write(obj.location)
      ..writeByte(4)
      ..write(obj.allDay)
      ..writeByte(5)
      ..write(obj.startAt)
      ..writeByte(6)
      ..write(obj.endAt)
      ..writeByte(7)
      ..write(obj.recurrence)
      ..writeByte(8)
      ..write(obj.reminders)
      ..writeByte(9)
      ..write(obj.colorIndex)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
