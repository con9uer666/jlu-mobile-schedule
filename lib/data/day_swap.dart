import 'package:hive/hive.dart';

/// 将某个日期整天改为另一日期的固定课表。
@HiveType(typeId: 8)
class DaySwap extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  DateTime targetDate;
  @HiveField(2)
  DateTime sourceDate;

  DaySwap({required this.id, required this.targetDate, required this.sourceDate});
}
