import '../data/course.dart';
import '../data/course_override.dart';
import '../data/course_reminder_setting.dart';
import '../data/day_swap.dart';
import '../data/event_item.dart';
import '../data/semester.dart';
import '../data/study_item.dart';
import 'course_schedule.dart';
import 'recurrence.dart';
import 'weekly_digest.dart';

class PlannedNotification {
  const PlannedNotification({
    required this.key,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.payload,
  });
  final String key;
  final String title;
  final String body;
  final DateTime fireAt;
  final String payload;
}

/// Merge all reminder types before applying the platform limit so that a
/// distant assignment can never displace tomorrow's class or exam reminder.
List<PlannedNotification> buildNotificationPlan({
  required DateTime now,
  required List<StudyItem> studyItems,
  required List<EventItem> events,
  required List<Course> courses,
  required Map<String, CourseReminderSetting> courseReminders,
  Semester? semester,
  List<CourseOverride> overrides = const [],
  List<DaySwap> daySwaps = const [],
  bool coursesGlobalEnabled = true,
  int defaultCourseLeadMinutes = 10,
  bool weeklyDigestEnabled = true,
  int limit = 64,
  int horizonDays = 365,
}) {
  final candidates = <String, PlannedNotification>{};
  final end = DateTime(now.year, now.month, now.day + horizonDays + 1);
  void add(
    String key,
    String title,
    String body,
    DateTime fire,
    String payload,
  ) {
    if (!fire.isAfter(now) || !fire.isBefore(end)) return;
    candidates[key] = PlannedNotification(
      key: key,
      title: title,
      body: body,
      fireAt: fire,
      payload: payload,
    );
  }

  for (final item in studyItems.where((i) => !i.isCompleted)) {
    for (final minutes in item.reminderMinutes.toSet()) {
      final kind = switch (item.kind) {
        StudyItemKind.assignment => '作业',
        StudyItemKind.exam => '考试',
        StudyItemKind.personal => '待办',
      };
      add(
        'study:${item.id}:$minutes',
        item.title,
        '$kind · ${minutes == 0 ? '现在开始' : '提前 $minutes 分钟'}',
        item.startAt.subtract(Duration(minutes: minutes)),
        'schedule://study?id=${Uri.encodeQueryComponent(item.id)}',
      );
    }
  }
  for (final event in events.where((e) => e.reminders.isNotEmpty)) {
    final maxLead = event.reminders
        .map((r) => r.leadTime)
        .reduce((a, b) => a > b ? a : b);
    for (final occurrence in expandOccurrences(
      event: event,
      windowStart: now,
      windowEnd: end.add(maxLead),
      maxCount: horizonDays * 7 + 100,
    )) {
      for (final reminder in event.reminders) {
        final lead = reminder.leadTime;
        add(
          'event:${event.id}:${occurrence.startAt.toIso8601String()}:${lead.inSeconds}',
          event.title,
          [
            reminder.label(),
            if (event.location?.isNotEmpty == true) event.location!,
            if (event.note?.isNotEmpty == true) event.note!,
          ].join(' · '),
          occurrence.startAt.subtract(lead),
          'schedule://event?id=${Uri.encodeQueryComponent(event.id)}',
        );
      }
    }
  }
  if (semester != null && coursesGlobalEnabled) {
    for (var i = 0; i <= horizonDays; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      for (final entry in resolveDateCourses(
        semester: semester,
        courses: courses,
        overrides: overrides,
        daySwaps: daySwaps,
        date: day,
      )) {
        final setting = courseReminders[entry.course.id];
        if (setting?.enabled == false) continue;
        final lead = setting?.leadMinutes ?? defaultCourseLeadMinutes;
        final time = semester.sectionStart(entry.startSection).split(':');
        if (time.length != 2) continue;
        final hour = int.tryParse(time[0]);
        final minute = int.tryParse(time[1]);
        if (hour == null || minute == null) continue;
        final start = DateTime(day.year, day.month, day.day, hour, minute);
        add(
          'course:${entry.course.id}:${start.toIso8601String()}',
          entry.course.name,
          '$lead 分钟后于 ${semester.sectionStart(entry.startSection)} 开始 · ${entry.location}',
          start.subtract(Duration(minutes: lead)),
          'schedule://course?id=${Uri.encodeQueryComponent(entry.course.id)}',
        );
      }
    }
  }
  if (weeklyDigestEnabled) {
    var sunday = WeeklyDigest.nextSunday(now);
    while (sunday.isBefore(end)) {
      add(
        'digest:${sunday.toIso8601String()}',
        '下周预报',
        WeeklyDigest.buildBody(
          target: sunday,
          semester: semester,
          courses: courses,
          events: events,
          overrides: overrides,
          daySwaps: daySwaps,
          studyItems: studyItems,
        ),
        sunday,
        'schedule://agenda',
      );
      sunday = DateTime(sunday.year, sunday.month, sunday.day + 7, 21);
    }
  }
  final sorted = candidates.values.toList()
    ..sort((a, b) {
      final time = a.fireAt.compareTo(b.fireAt);
      return time == 0 ? a.key.compareTo(b.key) : time;
    });
  return sorted.take(limit).toList();
}
