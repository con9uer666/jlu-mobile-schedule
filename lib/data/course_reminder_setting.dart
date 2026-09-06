import 'package:hive/hive.dart';

part 'course_reminder_setting.g.dart';

/// 每门课的提醒开关。独立 box(key = courseId),
/// 不动 Course 模型,重新导入课表不会清掉用户偏好。
@HiveType(typeId: 7)
class CourseReminderSetting extends HiveObject {
  @HiveField(0)
  String courseId;

  @HiveField(1)
  bool enabled;

  @HiveField(2)
  int leadMinutes;

  CourseReminderSetting({
    required this.courseId,
    this.enabled = false,
    this.leadMinutes = 10,
  });
}
