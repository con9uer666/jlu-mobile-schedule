import '../data/course.dart';
import '../data/course_override.dart';
import '../data/day_swap.dart';
import '../data/semester.dart';

class EffectiveCourse {
  EffectiveCourse({
    required this.course,
    required this.dayOfWeek,
    required this.startSection,
    required this.endSection,
    required this.location,
    required this.isAdjusted,
  });
  final Course course;
  final int dayOfWeek;
  final int startSection;
  final int endSection;
  final String location;
  final bool isAdjusted;
}

bool sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// A day replacement copies the source's fixed courses, preserving the source
/// day and adjustments on every other target day.
List<EffectiveCourse> resolveDateCourses({
  required Semester semester,
  required List<Course> courses,
  List<CourseOverride> overrides = const [],
  List<DaySwap> daySwaps = const [],
  required DateTime date,
}) {
  final week = semester.currentWeek(date);
  if (week < 1 || week > semester.totalWeeks) return [];
  final swap = daySwaps.where((s) => sameDate(s.targetDate, date)).lastOrNull;
  final source = swap?.sourceDate ?? date;
  final sourceWeek = semester.currentWeek(source);
  if (sourceWeek < 1 || sourceWeek > semester.totalWeeks) return [];
  final changes = {
    for (final o in overrides.where((o) => o.week == week)) o.courseId: o,
  };
  final result = <EffectiveCourse>[];
  for (final course in courses) {
    if (!course.id.startsWith('${semester.id}-') ||
        !course.activeInWeek(sourceWeek)) {
      continue;
    }
    final change = swap == null ? changes[course.id] : null;
    if (change?.isCancel == true) continue;
    final moved = change?.isMove == true;
    final weekday = moved ? change!.newDayOfWeek : course.dayOfWeek;
    if (weekday != source.weekday) continue;
    result.add(
      EffectiveCourse(
        course: course,
        dayOfWeek: date.weekday,
        startSection: moved ? change!.newStartSection : course.startSection,
        endSection: moved ? change!.newEndSection : course.endSection,
        location: moved && (change!.newLocation?.isNotEmpty ?? false)
            ? change.newLocation!
            : course.location,
        isAdjusted: swap != null || moved,
      ),
    );
  }
  result.sort((a, b) => a.startSection.compareTo(b.startSection));
  return result;
}

List<EffectiveCourse> resolveWeekCourses({
  required Semester semester,
  required List<Course> courses,
  List<CourseOverride> overrides = const [],
  List<DaySwap> daySwaps = const [],
  required int week,
}) => [
  for (var i = 0; i < 7; i++)
    ...resolveDateCourses(
      semester: semester,
      courses: courses,
      overrides: overrides,
      daySwaps: daySwaps,
      date: DateTime(
        semester.startDate.year,
        semester.startDate.month,
        semester.startDate.day + (week - 1) * 7 + i,
      ),
    ),
];
