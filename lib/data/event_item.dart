import 'package:hive/hive.dart';

import 'recurrence_rule.dart';
import 'reminder.dart';

part 'event_item.g.dart';

@HiveType(typeId: 4)
class EventItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? note;

  @HiveField(3)
  String? location;

  @HiveField(4)
  bool allDay;

  /// 第一次发生的本地 wall-clock 时间。所有重复 occurrence 以这个为基准。
  @HiveField(5)
  DateTime startAt;

  @HiveField(6)
  DateTime endAt;

  @HiveField(7)
  RecurrenceRule? recurrence;

  @HiveField(8)
  List<Reminder> reminders;

  @HiveField(9)
  int colorIndex;

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  DateTime updatedAt;

  EventItem({
    required this.id,
    required this.title,
    this.note,
    this.location,
    this.allDay = false,
    required this.startAt,
    required this.endAt,
    this.recurrence,
    List<Reminder>? reminders,
    this.colorIndex = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : reminders = reminders ?? <Reminder>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Duration get duration => endAt.difference(startAt);
}
