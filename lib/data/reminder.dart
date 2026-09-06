import 'package:hive/hive.dart';

part 'reminder.g.dart';

@HiveType(typeId: 11)
enum ReminderUnit {
  @HiveField(0)
  minute,
  @HiveField(1)
  hour,
  @HiveField(2)
  day,
  @HiveField(3)
  week,
}

@HiveType(typeId: 6)
class Reminder extends HiveObject {
  /// 提前 [amount] 个 [unit] 触发提醒。amount=0 表示准时。
  @HiveField(0)
  int amount;

  @HiveField(1)
  ReminderUnit unit;

  Reminder({this.amount = 0, this.unit = ReminderUnit.minute});

  Duration get leadTime {
    switch (unit) {
      case ReminderUnit.minute:
        return Duration(minutes: amount);
      case ReminderUnit.hour:
        return Duration(hours: amount);
      case ReminderUnit.day:
        return Duration(days: amount);
      case ReminderUnit.week:
        return Duration(days: amount * 7);
    }
  }

  String label() {
    if (amount == 0) return '准时';
    final unitName = switch (unit) {
      ReminderUnit.minute => '分钟',
      ReminderUnit.hour => '小时',
      ReminderUnit.day => '天',
      ReminderUnit.week => '周',
    };
    return '提前 $amount $unitName';
  }
}
