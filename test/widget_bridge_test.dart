import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/course.dart';
import 'package:schedule/data/course_override.dart';
import 'package:schedule/data/day_swap.dart';
import 'package:schedule/data/semester.dart';
import 'package:schedule/services/widget_bridge.dart';

void main() {
  final semester = Semester(
    id: 'current',
    name: '当前学期',
    startDate: DateTime(2026, 9, 7),
  );

  Course course({
    required String id,
    required String name,
    required int day,
    required List<int> weeks,
    int startSection = 1,
  }) {
    return Course(
      id: id,
      name: name,
      teacher: '教师',
      location: '教室',
      dayOfWeek: day,
      startSection: startSection,
      endSection: startSection + 1,
      weeks: weeks,
    );
  }

  test('小组件只包含当前学期的课程', () {
    final payload = WidgetBridge.buildPayload(
      semester: semester,
      allCourses: [
        course(
          id: 'current-1',
          name: '当前学期课程',
          day: DateTime.monday,
          weeks: [1],
        ),
        course(id: 'old-1', name: '旧学期课程', day: DateTime.monday, weeks: [1]),
      ],
      overrides: const [],
      now: DateTime(2026, 9, 7, 7),
    );

    final courses = payload['courses'] as List<dynamic>;
    expect(courses.map((item) => item['name']), ['当前学期课程']);
  });

  test('周日的明日课程使用下一周周次', () {
    final payload = WidgetBridge.buildPayload(
      semester: semester,
      allCourses: [
        course(
          id: 'current-1',
          name: '第二周周一课程',
          day: DateTime.monday,
          weeks: [2],
        ),
      ],
      overrides: const [],
      now: DateTime(2026, 9, 13, 20),
    );

    final tomorrow = payload['tomorrowCourses'] as List<dynamic>;
    expect(tomorrow.map((item) => item['name']), ['第二周周一课程']);
  });

  test('整天调课使用来源日期的固定课表', () {
    final thursdayCourse = course(
      id: 'current-1',
      name: '周四课程',
      day: DateTime.thursday,
      weeks: [1],
      startSection: 3,
    );
    final payload = WidgetBridge.buildPayload(
      semester: semester,
      allCourses: [thursdayCourse],
      overrides: [
        CourseOverride(
          id: 'current-1@1',
          courseId: 'current-1',
          week: 1,
          kind: CourseOverride.kindCancel,
        ),
      ],
      daySwaps: [
        DaySwap(
          id: '2026-09-08',
          targetDate: DateTime(2026, 9, 8),
          sourceDate: DateTime(2026, 9, 10),
        ),
      ],
      now: DateTime(2026, 9, 8, 7),
    );

    final courses = payload['courses'] as List<dynamic>;
    expect(courses.map((item) => item['name']), ['周四课程']);
    expect(courses.single['startSection'], 3);
  });
}
