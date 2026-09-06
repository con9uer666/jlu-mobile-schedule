import 'package:hive/hive.dart';

part 'recurrence_rule.g.dart';

@HiveType(typeId: 10)
enum RecurrenceFreq {
  @HiveField(0)
  none,
  @HiveField(1)
  daily,
  @HiveField(2)
  weekly,
  @HiveField(3)
  monthly,
  @HiveField(4)
  yearly,
}

@HiveType(typeId: 5)
class RecurrenceRule extends HiveObject {
  @HiveField(0)
  RecurrenceFreq freq;

  /// 每 [interval] 个 freq 单位发生一次。默认 1。
  @HiveField(1)
  int interval;

  /// weekly 时使用,1..7(Mon..Sun)。空表示用 anchor 的 weekday。
  @HiveField(2)
  List<int>? byWeekday;

  /// monthly 时使用,1..31。空表示用 anchor 的 day。
  @HiveField(3)
  List<int>? byMonthDay;

  /// 截止日,含当天。null 表示无限。优先于 [count]。
  @HiveField(4)
  DateTime? until;

  /// 总次数。null 表示无限。和 [until] 互斥(都给优先 [until])。
  @HiveField(5)
  int? count;

  RecurrenceRule({
    this.freq = RecurrenceFreq.none,
    this.interval = 1,
    this.byWeekday,
    this.byMonthDay,
    this.until,
    this.count,
  });

  bool get isNever => freq == RecurrenceFreq.none;

  String summary() {
    if (isNever) return '永不';
    final unit = switch (freq) {
      RecurrenceFreq.daily => '天',
      RecurrenceFreq.weekly => '周',
      RecurrenceFreq.monthly => '月',
      RecurrenceFreq.yearly => '年',
      RecurrenceFreq.none => '',
    };
    final prefix = interval == 1 ? '每$unit' : '每 $interval $unit';
    final tail = until != null
        ? ',直到 ${until!.year}/${until!.month}/${until!.day}'
        : (count != null ? ',共 $count 次' : '');
    return '$prefix$tail';
  }
}
