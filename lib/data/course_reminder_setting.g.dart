// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_reminder_setting.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CourseReminderSettingAdapter extends TypeAdapter<CourseReminderSetting> {
  @override
  final int typeId = 7;

  @override
  CourseReminderSetting read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CourseReminderSetting(
      courseId: fields[0] as String,
      enabled: fields[1] as bool,
      leadMinutes: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CourseReminderSetting obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.courseId)
      ..writeByte(1)
      ..write(obj.enabled)
      ..writeByte(2)
      ..write(obj.leadMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseReminderSettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
