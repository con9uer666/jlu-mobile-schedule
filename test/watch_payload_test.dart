import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/course.dart';
import 'package:schedule/data/course_override.dart';
import 'package:schedule/data/day_swap.dart';
import 'package:schedule/data/semester.dart';
import 'package:schedule/services/widget_bridge.dart';

void main() {
  final semester = Semester(
    id: 'current',
    name: '秋季学期',
    startDate: DateTime(2026, 9, 7),
    totalWeeks: 2,
  );
  Course course(String id, int day, List<int> weeks) => Course(
    id: id,
    name: id,
    teacher: '',
    location: '一教302',
    dayOfWeek: day,
    startSection: 1,
    endSection: 2,
    weeks: weeks,
  );
  Map<String, dynamic> build({
    List<Course>? courses,
    List<CourseOverride> overrides = const [],
    List<DaySwap> swaps = const [],
  }) => WidgetBridge.buildWatchPayload(
    semester: semester,
    allCourses:
        courses ??
        [
          course('current-one', 1, [1]),
          course('current-two', 1, [2]),
          course('old-one', 1, [1, 2]),
        ],
    overrides: overrides,
    daySwaps: swaps,
    now: DateTime(2026, 9, 8),
  );
  List<dynamic> on(Map<String, dynamic> payload, String date) =>
      (payload['days'] as List).firstWhere(
            (day) => day['date'] == date,
          )['courses']
          as List;

  test(
    'exports every date of current semester and excludes other semesters',
    () {
      final payload = build();
      expect(payload['startDate'], '2026-09-07');
      expect(payload['endDate'], '2026-09-20');
      expect((payload['days'] as List).length, 14);
      expect(on(payload, '2026-09-07').single['id'], 'current-one');
      expect(on(payload, '2026-09-14').single['id'], 'current-two');
      expect(on(payload, '2026-09-08'), isEmpty);
    },
  );
  test('move and cancellation are reflected in all semester dates', () {
    final payload = build(
      overrides: [
        CourseOverride(
          id: 'current-one@1',
          courseId: 'current-one',
          week: 1,
          kind: CourseOverride.kindMove,
          newDayOfWeek: 2,
          newStartSection: 3,
          newEndSection: 4,
          newLocation: '二教101',
        ),
        CourseOverride(
          id: 'current-two@2',
          courseId: 'current-two',
          week: 2,
          kind: CourseOverride.kindCancel,
        ),
      ],
    );
    expect(on(payload, '2026-09-07'), isEmpty);
    expect(on(payload, '2026-09-14'), isEmpty);
    final moved = on(payload, '2026-09-08').single;
    expect(moved['location'], '二教101');
    expect(moved['startTime'], '10:00');
    expect(moved['endTime'], '11:40');
  });
  test('whole-day swap uses the actual source week', () {
    final payload = build(
      swaps: [
        DaySwap(
          id: 'swap',
          targetDate: DateTime(2026, 9, 8),
          sourceDate: DateTime(2026, 9, 14),
        ),
      ],
    );
    expect(on(payload, '2026-09-08').single['id'], 'current-two');
  });
  test('clearing semester produces an empty replacement snapshot', () {
    final payload = WidgetBridge.buildWatchPayload(
      semester: null,
      allCourses: [
        course('current-one', 1, [1]),
      ],
      now: DateTime(2026, 9, 8),
    );
    expect(payload['semesterId'], isNull);
    expect(payload['days'], isEmpty);
    expect(payload['startDate'], isNull);
  });
}
