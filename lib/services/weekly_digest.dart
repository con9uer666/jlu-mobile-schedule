import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/event_item.dart';
import '../data/storage.dart';

const int _weeklyDigestNotifId = 990001;

class WeeklyDigest {
  WeeklyDigest._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// 调度本周日 21:00(若已过则下周日)的预报通知。
  /// 每次调用都先取消旧的,用最新数据重新生成 body。
  static Future<void> maybeSchedule({
    required bool enabled,
    required dynamic semester, // Semester?,这里避免引入循环
  }) async {
    await _plugin.cancel(_weeklyDigestNotifId);
    if (!enabled) return;
    final now = DateTime.now();
    final target = _nextSundayAt(now, 21, 0);
    final body = _generateBody(now, target, semester);
    final fireTz = tz.TZDateTime.from(target, tz.local);
    await _plugin.zonedSchedule(
      _weeklyDigestNotifId,
      '下周预报',
      body,
      fireTz,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'schedule://agenda',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static DateTime _nextSundayAt(DateTime now, int hour, int minute) {
    // weekday: Mon=1..Sun=7
    int daysToSunday = (7 - now.weekday) % 7;
    DateTime candidate = DateTime(
      now.year,
      now.month,
      now.day + daysToSunday,
      hour,
      minute,
    );
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  static String _generateBody(
    DateTime now,
    DateTime target,
    dynamic semester,
  ) {
    // target = 周日 21:00,下周从 target 之后开始
    final nextMonday = target.add(const Duration(days: 1));
    final nextSunday = nextMonday.add(const Duration(days: 7));

    // 课程数
    int courseCount = 0;
    if (semester != null) {
      final courses = AppStorage.courses.values.toList();
      for (int offset = 0; offset < 7; offset++) {
        final day = nextMonday.add(Duration(days: offset));
        final week = semester.currentWeek(day);
        if (week < 1 || week > semester.totalWeeks) continue;
        for (final c in courses) {
          if (c.dayOfWeek == day.weekday && c.activeInWeek(week)) {
            courseCount++;
          }
        }
      }
    }

    // 日程数(下周内开始的 event)
    int eventCount = 0;
    final events = AppStorage.events.values.toList();
    for (final EventItem e in events) {
      if (e.startAt.isAfter(nextMonday.subtract(const Duration(seconds: 1))) &&
          e.startAt.isBefore(nextSunday.add(const Duration(days: 1)))) {
        eventCount++;
      }
    }

    final parts = <String>[];
    if (courseCount > 0) parts.add('$courseCount 节课');
    if (eventCount > 0) parts.add('$eventCount 个日程');
    if (parts.isEmpty) return '下周暂无安排,好好休息。';
    return '下周共 ${parts.join('、')}。';
  }
}
