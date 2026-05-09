import 'package:hive/hive.dart';

import 'semester.dart';

class SemesterAdapter extends TypeAdapter<Semester> {
  @override
  final int typeId = 2;

  @override
  Semester read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final sectionCount = fields[4] as int? ?? 12;
    return Semester(
      id: fields[0] as String,
      name: fields[1] as String,
      startDate: fields[2] as DateTime,
      totalWeeks: fields[3] as int? ?? 20,
      sectionCount: sectionCount,
      sectionClock: (fields[5] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Semester obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.name)
      ..writeByte(2)..write(obj.startDate)
      ..writeByte(3)..write(obj.totalWeeks)
      ..writeByte(4)..write(obj.sectionCount)
      ..writeByte(5)..write(obj.sectionClock);
  }
}
