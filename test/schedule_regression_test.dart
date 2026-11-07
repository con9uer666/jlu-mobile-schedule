import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/course_override.dart';
import 'package:schedule/data/day_swap.dart';
import 'package:schedule/services/course_schedule.dart';
import 'package:schedule/services/section_time.dart';
import 'package:schedule/services/widget_bridge.dart';
import 'package:schedule/data/providers/jlu_iedu.dart';
import 'package:schedule/data/providers/hhu_jsxsd.dart';
import 'support/fixtures.dart';

void main() {
  final sem = semester();
  final swap = DaySwap(
    id: 'swap',
    targetDate: DateTime(2026, 9, 8),
    sourceDate: DateTime(2026, 9, 10),
  );
  test('semester distinguishes pre-term, last day and post-term', () {
    expect(sem.currentWeek(DateTime(2026, 9, 6, 23, 59)), 0);
    expect(sem.currentWeek(DateTime(2026, 9, 20, 23, 59)), 2);
    expect(sem.currentWeek(DateTime(2026, 9, 21)), 3);
  });
  test('whole-day replacement preserves the source day', () {
    final result = resolveWeekCourses(
      semester: sem,
      courses: [course(day: 4)],
      daySwaps: [swap],
      week: 1,
    );
    expect(result.map((c) => c.dayOfWeek), [2, 4]);
  });
  test('whole-day replacement preserves unrelated cancellation and move', () {
    final result = resolveWeekCourses(
      semester: sem,
      courses: [
        course(),
        course(id: 's-1', day: 3),
      ],
      overrides: [
        CourseOverride(
          id: 'cancel',
          courseId: 's-0',
          week: 1,
          kind: CourseOverride.kindCancel,
        ),
        CourseOverride(
          id: 'move',
          courseId: 's-1',
          week: 1,
          kind: CourseOverride.kindMove,
          newDayOfWeek: 5,
          newStartSection: 3,
          newEndSection: 4,
        ),
      ],
      daySwaps: [swap],
      week: 1,
    );
    expect(result.map((c) => c.dayOfWeek), [5]);
  });
  test('copy uses source week, even for multiple targets', () {
    final result = resolveWeekCourses(
      semester: sem,
      courses: [
        course(weeks: [2]),
      ],
      daySwaps: [
        DaySwap(
          id: 'a',
          targetDate: DateTime(2026, 9, 8),
          sourceDate: DateTime(2026, 9, 14),
        ),
        DaySwap(
          id: 'b',
          targetDate: DateTime(2026, 9, 9),
          sourceDate: DateTime(2026, 9, 14),
        ),
      ],
      week: 1,
    );
    expect(result.map((c) => c.dayOfWeek), [2, 3]);
  });
  test('expired semester has no daily courses or notifications', () {
    expect(
      resolveDateCourses(
        semester: sem,
        courses: [course()],
        date: DateTime(2026, 9, 21),
      ),
      isEmpty,
    );
    final payload = WidgetBridge.buildPayload(
      semester: sem,
      allCourses: [course()],
      overrides: [],
      now: DateTime(2026, 9, 21),
    );
    expect(payload['courses'], isEmpty);
    expect(payload['weekLabel'], '学期已结束');
  });
  test('phone widget caches future dates and uses next week correctly', () {
    final payload = WidgetBridge.buildPayload(
      semester: sem,
      allCourses: [
        course(weeks: [2]),
      ],
      overrides: [],
      now: DateTime(2026, 9, 7),
    );
    final days = payload['days'] as Map;
    expect(days['2026-09-07']['courses'], isEmpty);
    expect((days['2026-09-14']['courses'] as List).single['id'], 's-0');
    expect(days['2026-09-14']['weekLabel'], '第 2 周');
    expect(days['2026-09-21']['courses'], isEmpty);
  });
  test('empty day never claims a class is in progress', () {
    expect(
      currentStatus(sem, DateTime(2026, 9, 7, 8, 10), courses: []).noClass,
      isTrue,
    );
  });
  test('status skips unoccupied sections and honors moved courses', () {
    final entries = resolveDateCourses(
      semester: sem,
      courses: [course(start: 3, end: 4)],
      date: DateTime(2026, 9, 7),
    );
    final status = currentStatus(
      sem,
      DateTime(2026, 9, 7, 8, 10),
      courses: entries,
    );
    expect(status.inClass, isFalse);
    expect(status.toNext, const Duration(hours: 1, minutes: 50));
    expect(
      currentStatus(
        sem,
        DateTime(2026, 9, 7, 10, 10),
        courses: entries,
      ).section,
      3,
    );
  });
  test('login matching rejects HTTP and lookalike domains', () {
    const jlu = JluIeduProvider();
    const hhu = HhuJsxsdProvider();
    expect(
      jlu.isLoggedIn('https://iedu.jlu.edu.cn/jwapp/sys/wdkb/index.do'),
      isTrue,
    );
    expect(
      jlu.isLoggedIn('https://evil.example/iedu.jlu.edu.cn/jwapp/sys/wdkb/'),
      isFalse,
    );
    expect(jlu.isLoggedIn('http://iedu.jlu.edu.cn/jwapp/sys/wdkb/'), isFalse);
    expect(hhu.isLoggedIn('https://jwxt.hhu.edu.cn/jsxsd/xskb/'), isTrue);
    expect(
      hhu.isLoggedIn('https://evil.example/jwxt.hhu.edu.cn/jsxsd/xskb/'),
      isFalse,
    );
  });
}
