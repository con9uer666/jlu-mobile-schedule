import 'package:hive/hive.dart';

import 'course_override.dart';

class CourseOverrideAdapter extends TypeAdapter<CourseOverride> {
  @override
  final int typeId = 3;

  @override
  CourseOverride read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CourseOverride(
      id: fields[0] as String,
      courseId: fields[1] as String,
      week: fields[2] as int,
      kind: fields[3] as int,
      newDayOfWeek: fields[4] as int? ?? 1,
      newStartSection: fields[5] as int? ?? 1,
      newEndSection: fields[6] as int? ?? 1,
      newLocation: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CourseOverride obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.courseId)
      ..writeByte(2)..write(obj.week)
      ..writeByte(3)..write(obj.kind)
      ..writeByte(4)..write(obj.newDayOfWeek)
      ..writeByte(5)..write(obj.newStartSection)
      ..writeByte(6)..write(obj.newEndSection)
      ..writeByte(7)..write(obj.newLocation);
  }
}
