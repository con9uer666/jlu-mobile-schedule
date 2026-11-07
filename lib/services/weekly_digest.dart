import '../data/course.dart';
import '../data/course_override.dart';
import '../data/day_swap.dart';
import '../data/event_item.dart';
import '../data/semester.dart';
import '../data/study_item.dart';
import 'course_schedule.dart';
import 'recurrence.dart';

class WeeklyDigest {
  WeeklyDigest._();

  static DateTime nextSunday(DateTime now) {
    final target = DateTime(
      now.year,
      now.month,
      now.day + (7 - now.weekday) % 7,
      21,
    );
    return target.isAfter(now)
        ? target
        : DateTime(target.year, target.month, target.day + 7, 21);
  }

  static String buildBody({
    required DateTime target,
    required Semester? semester,
    required List<Course> courses,
    required List<EventItem> events,
    List<CourseOverride> overrides = const [],
    List<DaySwap> daySwaps = const [],
    List<StudyItem> studyItems = const [],
  }) {
    final monday = DateTime(target.year, target.month, target.day + 1);
    final end = DateTime(monday.year, monday.month, monday.day + 7);
    var courseCount = 0;
    if (semester != null) {
      for (var i = 0; i < 7; i++) {
        courseCount += resolveDateCourses(
          semester: semester,
          courses: courses,
          overrides: overrides,
          daySwaps: daySwaps,
          date: DateTime(monday.year, monday.month, monday.day + i),
        ).length;
      }
    }
    final eventCount = events.fold<int>(
      0,
      (count, event) =>
          count +
          expandOccurrences(
                event: event,
                windowStart: monday,
                windowEnd: end,
                maxCount: 1000,
              )
              .where(
                (o) => !o.startAt.isBefore(monday) && o.startAt.isBefore(end),
              )
              .length,
    );
    final tasks = studyItems.where(
      (i) =>
          !i.isCompleted &&
          !i.startAt.isBefore(monday) &&
          i.startAt.isBefore(end),
    );
    final parts = <String>[
      if (courseCount > 0) '$courseCount 节课',
      if (eventCount > 0) '$eventCount 个日程',
      for (final entry in [
        (StudyItemKind.assignment, '项作业'),
        (StudyItemKind.exam, '场考试'),
        (StudyItemKind.personal, '项待办'),
      ])
        if (tasks.where((i) => i.kind == entry.$1).isNotEmpty)
          '${tasks.where((i) => i.kind == entry.$1).length} ${entry.$2}',
    ];
    return parts.isEmpty ? '下周暂无安排，好好休息。' : '下周共 ${parts.join('、')}。';
  }
}
