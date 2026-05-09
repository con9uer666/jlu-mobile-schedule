import 'package:hive/hive.dart';

import 'course.dart';

class CourseAdapter extends TypeAdapter<Course> {
  @override
  final int typeId = 1;

  @override
  Course read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Course(
      id: fields[0] as String,
      name: fields[1] as String,
      teacher: fields[2] as String,
      location: fields[3] as String,
      dayOfWeek: fields[4] as int,
      startSection: fields[5] as int,
      endSection: fields[6] as int,
      weeks: (fields[7] as List).cast<int>(),
      colorIndex: fields[8] as int? ?? 0,
      remark: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Course obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.name)
      ..writeByte(2)..write(obj.teacher)
      ..writeByte(3)..write(obj.location)
      ..writeByte(4)..write(obj.dayOfWeek)
      ..writeByte(5)..write(obj.startSection)
      ..writeByte(6)..write(obj.endSection)
      ..writeByte(7)..write(obj.weeks)
      ..writeByte(8)..write(obj.colorIndex)
      ..writeByte(9)..write(obj.remark);
  }
}
