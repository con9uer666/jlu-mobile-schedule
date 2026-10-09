import 'package:hive/hive.dart';

enum StudyItemKind { assignment, exam, personal }

class StudyItem extends HiveObject {
  StudyItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.startAt,
    this.endAt,
    this.courseId,
    this.location,
    this.submissionMethod,
    this.allDay = false,
    List<int>? reminderMinutes,
    this.completedAt,
    DateTime? createdAt,
  }) : reminderMinutes = reminderMinutes ?? defaultReminders(kind),
       createdAt = createdAt ?? DateTime.now();

  String id;
  StudyItemKind kind;
  String title;
  DateTime startAt;
  DateTime? endAt;
  String? courseId;
  String? location;
  String? submissionMethod;
  bool allDay;
  List<int> reminderMinutes;
  DateTime? completedAt;
  DateTime createdAt;

  bool get isCompleted => completedAt != null;
  DateTime get timelineAt => startAt;

  static List<int> defaultReminders(StudyItemKind kind) => switch (kind) {
    StudyItemKind.assignment => [24 * 60, 60],
    StudyItemKind.exam => [24 * 60, 120],
    StudyItemKind.personal => [60],
  };
}

class StudyItemAdapter extends TypeAdapter<StudyItem> {
  @override
  final int typeId = 12;

  @override
  StudyItem read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };
    return StudyItem(
      id: fields[0] as String,
      kind: StudyItemKind.values[(fields[1] as int).clamp(0, 2)],
      title: fields[2] as String,
      startAt: fields[3] as DateTime,
      endAt: fields[4] as DateTime?,
      courseId: fields[5] as String?,
      location: fields[6] as String?,
      submissionMethod: fields[7] as String?,
      allDay: fields[8] as bool? ?? false,
      reminderMinutes: (fields[9] as List?)?.cast<int>(),
      completedAt: fields[10] as DateTime?,
      createdAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, StudyItem item) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(item.id)
      ..writeByte(1)
      ..write(item.kind.index)
      ..writeByte(2)
      ..write(item.title)
      ..writeByte(3)
      ..write(item.startAt)
      ..writeByte(4)
      ..write(item.endAt)
      ..writeByte(5)
      ..write(item.courseId)
      ..writeByte(6)
      ..write(item.location)
      ..writeByte(7)
      ..write(item.submissionMethod)
      ..writeByte(8)
      ..write(item.allDay)
      ..writeByte(9)
      ..write(item.reminderMinutes)
      ..writeByte(10)
      ..write(item.completedAt)
      ..writeByte(11)
      ..write(item.createdAt);
  }
}
