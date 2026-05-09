import 'package:hive/hive.dart';

@HiveType(typeId: 2)
class Semester extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  DateTime startDate;

  @HiveField(3)
  int totalWeeks;

  @HiveField(4)
  int sectionCount;

  Semester({
    required this.id,
    required this.name,
    required this.startDate,
    this.totalWeeks = 20,
    this.sectionCount = 12,
  });

  int currentWeek(DateTime now) {
    final diff = now.difference(DateTime(startDate.year, startDate.month, startDate.day)).inDays;
    if (diff < 0) return 1;
    final week = diff ~/ 7 + 1;
    return week.clamp(1, totalWeeks);
  }
}
