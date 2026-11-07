import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/course_override.dart';
import 'package:schedule/data/day_swap.dart';
import 'package:schedule/data/event_item.dart';
import 'package:schedule/data/recurrence_rule.dart';
import 'package:schedule/data/reminder.dart';
import 'package:schedule/data/study_item.dart';
import 'package:schedule/services/notification_plan.dart';
import 'package:schedule/services/weekly_digest.dart';
import 'support/fixtures.dart';

void main() {
  final now = DateTime(2026, 9, 7, 7);
  final sem = semester(weeks: 20);
  EventItem event({
    List<Reminder>? reminders,
    DateTime? start,
    RecurrenceRule? rule,
  }) => EventItem(
    id: 'e',
    title: 'E',
    startAt: start ?? DateTime(2026, 9, 10, 10),
    endAt: (start ?? DateTime(2026, 9, 10, 10)).add(const Duration(hours: 1)),
    reminders: reminders ?? [Reminder()],
    recurrence: rule,
  );
  List<PlannedNotification> plan({
    List<EventItem> events = const [],
    List<StudyItem> tasks = const [],
    List<CourseOverride> changes = const [],
    List<DaySwap> swaps = const [],
    int limit = 400,
  }) => buildNotificationPlan(
    now: now,
    studyItems: tasks,
    events: events,
    courses: [course(weeks: List.generate(20, (i) => i + 1))],
    courseReminders: {},
    semester: sem,
    overrides: changes,
    daySwaps: swaps,
    weeklyDigestEnabled: false,
    limit: limit,
  );
  test('class reminders cover the whole semester and stop at its end', () {
    final result = plan();
    expect(result.length, 20);
    expect(result.last.fireAt, DateTime(2027, 1, 18, 7, 50));
    expect(result.any((n) => n.fireAt.isAfter(DateTime(2027, 1, 24))), isFalse);
  });
  test('cancellation and moved location/time are used by reminders', () {
    final result = plan(
      changes: [
        CourseOverride(
          id: 'cancel',
          courseId: 's-0',
          week: 1,
          kind: CourseOverride.kindCancel,
        ),
        CourseOverride(
          id: 'move',
          courseId: 's-0',
          week: 2,
          kind: CourseOverride.kindMove,
          newDayOfWeek: 2,
          newStartSection: 3,
          newEndSection: 4,
          newLocation: 'B202',
        ),
      ],
    );
    expect(result.first.fireAt, DateTime(2026, 9, 15, 9, 50));
    expect(result.first.body, contains('B202'));
  });
  test('day copies produce distinct reminders without removing source', () {
    final result = plan(
      swaps: [
        DaySwap(
          id: 'a',
          targetDate: DateTime(2026, 9, 8),
          sourceDate: DateTime(2026, 9, 7),
        ),
      ],
    );
    expect(result.take(2).map((n) => n.fireAt), [
      DateTime(2026, 9, 7, 7, 50),
      DateTime(2026, 9, 8, 7, 50),
    ]);
    expect(result.map((n) => n.key).toSet().length, result.length);
  });
  test('one-day and two-hour reminders stay distinct', () {
    final result = plan(
      events: [
        event(
          reminders: [
            Reminder(amount: 1, unit: ReminderUnit.day),
            Reminder(amount: 2, unit: ReminderUnit.hour),
          ],
        ),
      ],
    );
    final reminders = result
        .where((n) => n.payload.contains('//event'))
        .toList();
    expect(reminders.length, 2);
    expect(reminders.map((n) => n.key).toSet().length, 2);
    expect(reminders.map((n) => n.fireAt), [
      DateTime(2026, 9, 9, 10),
      DateTime(2026, 9, 10, 8),
    ]);
  });
  test(
    'nearest reminder wins regardless of source type or insertion order',
    () {
      final tasks = List.generate(
        70,
        (i) => StudyItem(
          id: '$i',
          kind: StudyItemKind.assignment,
          title: 'later',
          startAt: DateTime(2026, 12, 1),
          reminderMinutes: [60],
        ),
      );
      final result = plan(
        tasks: tasks,
        events: [event(start: DateTime(2026, 9, 7, 7, 30))],
        limit: 64,
      );
      expect(result.length, 64);
      expect(result.first.payload, contains('//event'));
      expect(result[1].payload, contains('//course'));
    },
  );
  test('recurrence honors selected weekday and never starts prematurely', () {
    final result = plan(
      events: [
        event(
          start: DateTime(2026, 9, 15, 10),
          rule: RecurrenceRule(freq: RecurrenceFreq.weekly, byWeekday: [5]),
        ),
      ],
    );
    final reminders = result
        .where((n) => n.payload.contains('//event'))
        .toList();
    expect(reminders.first.fireAt, DateTime(2026, 9, 18, 10));
    expect(reminders.every((n) => n.fireAt.weekday == 5), isTrue);
  });
  test(
    'weekly digest uses Monday midnight through next Monday exclusively',
    () {
      final body = WeeklyDigest.buildBody(
        target: DateTime(2026, 9, 6, 21),
        semester: null,
        courses: [],
        events: [
          event(start: DateTime(2026, 9, 7, 8)),
          event(start: DateTime(2026, 9, 14)),
          event(
            start: DateTime(2026, 9, 7, 12),
            rule: RecurrenceRule(freq: RecurrenceFreq.daily),
          ),
        ],
      );
      expect(body, contains('8 个日程'));
    },
  );
  test('digest counts adjusted courses and pending tasks', () {
    final body = WeeklyDigest.buildBody(
      target: DateTime(2026, 9, 6, 21),
      semester: sem,
      courses: [course()],
      events: [],
      overrides: [
        CourseOverride(
          id: 'c',
          courseId: 's-0',
          week: 1,
          kind: CourseOverride.kindCancel,
        ),
      ],
      studyItems: [
        StudyItem(
          id: 'task',
          kind: StudyItemKind.exam,
          title: 'exam',
          startAt: DateTime(2026, 9, 7, 8),
        ),
      ],
    );
    expect(body, contains('1 场考试'));
    expect(body, isNot(contains('节课')));
  });
}
