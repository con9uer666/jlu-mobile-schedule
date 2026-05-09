import 'package:hive/hive.dart';

/// 临时调课 / 停课一次。每条只针对某门课 + 某一周。
/// id 固定为 "${courseId}@${week}",保证同课同周幂等写入。
@HiveType(typeId: 3)
class CourseOverride extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String courseId;

  @HiveField(2)
  int week;

  /// 0 = 临时调课(用 newDayOfWeek / newStartSection / newEndSection / newLocation)
  /// 1 = 本周停课一次
  @HiveField(3)
  int kind;

  @HiveField(4)
  int newDayOfWeek;

  @HiveField(5)
  int newStartSection;

  @HiveField(6)
  int newEndSection;

  @HiveField(7)
  String? newLocation;

  CourseOverride({
    required this.id,
    required this.courseId,
    required this.week,
    required this.kind,
    this.newDayOfWeek = 1,
    this.newStartSection = 1,
    this.newEndSection = 1,
    this.newLocation,
  });

  static const int kindMove = 0;
  static const int kindCancel = 1;

  bool get isCancel => kind == kindCancel;
  bool get isMove => kind == kindMove;

  static String buildId(String courseId, int week) => '$courseId@$week';
}
