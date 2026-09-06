import 'package:hive/hive.dart';

@HiveType(typeId: 1)
class Course extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String teacher;

  @HiveField(3)
  String location;

  @HiveField(4)
  int dayOfWeek;

  @HiveField(5)
  int startSection;

  @HiveField(6)
  int endSection;

  @HiveField(7)
  List<int> weeks;

  @HiveField(8)
  int colorIndex;

  @HiveField(9)
  String? remark;

  Course({
    required this.id,
    required this.name,
    required this.teacher,
    required this.location,
    required this.dayOfWeek,
    required this.startSection,
    required this.endSection,
    required this.weeks,
    this.colorIndex = 0,
    this.remark,
  })  : assert(dayOfWeek >= 1 && dayOfWeek <= 7),
        assert(startSection >= 1),
        assert(endSection >= startSection);

  bool activeInWeek(int week) => weeks.contains(week);
}
