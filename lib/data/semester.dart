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

  /// 每一节的时间段,格式 "HH:mm-HH:mm",长度与 sectionCount 对齐。
  @HiveField(5)
  List<String> sectionClock;

  Semester({
    required this.id,
    required this.name,
    required this.startDate,
    this.totalWeeks = 20,
    this.sectionCount = 12,
    List<String>? sectionClock,
  }) : sectionClock = normalizeSectionClock(sectionClock, sectionCount);

  int currentWeek(DateTime now) {
    final diff = now
        .difference(DateTime(startDate.year, startDate.month, startDate.day))
        .inDays;
    if (diff < 0) return 0;
    final week = diff ~/ 7 + 1;
    return week.clamp(1, totalWeeks);
  }

  String sectionStart(int section) => _split(section).$1;
  String sectionEnd(int section) => _split(section).$2;

  (String, String) _split(int section) {
    if (section < 1 || section > sectionClock.length) return ('', '');
    final parts = sectionClock[section - 1].split('-');
    if (parts.length != 2) return ('', '');
    return (parts[0], parts[1]);
  }

  /// JLU 默认节次时间(覆盖 1~14 节),实际长度按 sectionCount 裁剪。
  static const List<String> _defaults = [
    '08:00-08:45',
    '08:55-09:40',
    '10:00-10:45',
    '10:55-11:40',
    '13:30-14:15',
    '14:25-15:10',
    '15:20-16:05',
    '16:15-17:00',
    '18:30-19:15',
    '19:25-20:10',
    '20:20-21:05',
    '21:15-22:00',
    '22:10-22:55',
    '23:05-23:50',
  ];

  /// 保证输出长度 == count。
  /// 不足就从默认表补,超出就截断;原有条目尽量保留。
  static List<String> normalizeSectionClock(List<String>? src, int count) {
    final base = src ?? const <String>[];
    return List<String>.generate(count, (i) {
      if (i < base.length && base[i].isNotEmpty) return base[i];
      if (i < _defaults.length) return _defaults[i];
      return '00:00-00:00';
    });
  }
}
