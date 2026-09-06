import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/course.dart';
import '../data/course_reminder_setting.dart';
import '../data/event_item.dart';
import '../data/recurrence_rule.dart';
import '../data/reminder.dart';
import '../data/semester.dart';
import 'recurrence.dart';

typedef DeepLinkHandler = void Function(Uri uri);

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static DeepLinkHandler? _deepLinkHandler;
  static bool _initialized = false;

  /// 在 main() 中尽早调用。串行,无网络。
  static Future<void> init({DeepLinkHandler? onDeepLink}) async {
    _deepLinkHandler = onDeepLink;
    tzdata.initializeTimeZones();
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      // 失败时 fallback 到 UTC,zonedSchedule 仍可用但时间含义偏移。
    }

    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(iOS: darwinInit, macOS: darwinInit),
      onDidReceiveNotificationResponse: _onTap,
    );
    _initialized = true;
  }

  static Future<bool> requestPermissions() async {
    if (!_initialized) return false;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final g = await ios.requestPermissions(alert: true, badge: true, sound: true);
      return g ?? false;
    }
    final mac = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    if (mac != null) {
      final g = await mac.requestPermissions(alert: true, badge: true, sound: true);
      return g ?? false;
    }
    return false;
  }

  static Future<bool> checkPermissionGranted() async {
    if (!_initialized) return false;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final s = await ios.checkPermissions();
      return s?.isEnabled ?? false;
    }
    final mac = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    if (mac != null) {
      final s = await mac.checkPermissions();
      return s?.isEnabled ?? false;
    }
    return false;
  }

  static void _onTap(NotificationResponse resp) {
    final payload = resp.payload;
    if (payload == null) return;
    final uri = Uri.tryParse(payload);
    if (uri == null) return;
    _deepLinkHandler?.call(uri);
  }

  /// 取消所有 + 重排未来 30 天的 events 和今天/明天的课程提醒。
  ///
  /// iOS 64 通知上限:events 优先,课程取剩余。
  static Future<void> rescheduleAll({
    required List<EventItem> events,
    required List<Course> courses,
    required Map<String, CourseReminderSetting> courseReminders,
    Semester? semester,
    bool coursesGlobalEnabled = true,
    int defaultCourseLeadMinutes = 10,
  }) async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    if (!await checkPermissionGranted()) return;

    int slotsLeft = 64;
    final now = DateTime.now();
    final eventWindowEnd = now.add(const Duration(days: 30));

    for (final e in events) {
      if (e.reminders.isEmpty) continue;
      slotsLeft = await _scheduleEvent(e, now, eventWindowEnd, slotsLeft);
      if (slotsLeft <= 0) return;
    }

    if (semester != null) {
      final t0 = DateTime(now.year, now.month, now.day);
      final courseWindowEnd = t0.add(const Duration(days: 2));
      slotsLeft = await _scheduleCourses(
        courses,
        courseReminders,
        semester,
        now,
        courseWindowEnd,
        slotsLeft,
        globalEnabled: coursesGlobalEnabled,
        defaultLeadMinutes: defaultCourseLeadMinutes,
      );
    }
  }

  static Future<int> _scheduleEvent(
    EventItem e,
    DateTime now,
    DateTime windowEnd,
    int slotsLeft,
  ) async {
    if (slotsLeft <= 0) return 0;

    final r = e.recurrence;
    final canUseRepeat = r != null &&
        r.freq != RecurrenceFreq.none &&
        r.interval == 1 &&
        r.until == null &&
        r.count == null &&
        (r.freq == RecurrenceFreq.daily ||
            (r.freq == RecurrenceFreq.weekly &&
                (r.byWeekday == null || r.byWeekday!.length <= 1)) ||
            (r.freq == RecurrenceFreq.monthly &&
                (r.byMonthDay == null || r.byMonthDay!.length <= 1)));

    if (canUseRepeat) {
      // 单 schedule 覆盖未来无限次发生,一个槽位即可(每条 reminder 一槽)。
      for (final rem in e.reminders) {
        if (slotsLeft <= 0) break;
        final fire = e.startAt.subtract(rem.leadTime);
        final fireTz = tz.TZDateTime.from(fire, tz.local);
        final id = _notifId(e.id, rem.amount * 100 + rem.unit.index);
        await _plugin.zonedSchedule(
          id,
          e.title,
          _bodyForEvent(e, rem),
          fireTz,
          _details(),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: _matchFor(r.freq),
          payload: 'schedule://event?id=${Uri.encodeQueryComponent(e.id)}',
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        slotsLeft--;
      }
      return slotsLeft;
    }

    // 复杂规则:展开后逐条 schedule。
    final occ = expandOccurrences(
      event: e,
      windowStart: now,
      windowEnd: windowEnd,
      maxCount: 30,
    );
    for (final o in occ) {
      for (final rem in e.reminders) {
        if (slotsLeft <= 0) return 0;
        final fire = o.startAt.subtract(rem.leadTime);
        if (fire.isBefore(now)) continue;
        final fireTz = tz.TZDateTime.from(fire, tz.local);
        final id = _notifId(e.id, o.index * 100 + rem.amount + rem.unit.index);
        await _plugin.zonedSchedule(
          id,
          e.title,
          _bodyForEvent(e, rem),
          fireTz,
          _details(),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'schedule://event?id=${Uri.encodeQueryComponent(e.id)}',
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        slotsLeft--;
      }
    }
    return slotsLeft;
  }

  static Future<int> _scheduleCourses(
    List<Course> courses,
    Map<String, CourseReminderSetting> reminders,
    Semester semester,
    DateTime now,
    DateTime windowEnd,
    int slotsLeft, {
    required bool globalEnabled,
    required int defaultLeadMinutes,
  }) async {
    if (slotsLeft <= 0) return 0;
    if (!globalEnabled) return slotsLeft;
    final t0 = DateTime(now.year, now.month, now.day);
    for (int dayOffset = 0; dayOffset <= 2; dayOffset++) {
      if (slotsLeft <= 0) break;
      final day = t0.add(Duration(days: dayOffset));
      if (day.isAfter(windowEnd)) break;
      final week = semester.currentWeek(day);
      if (week < 1 || week > semester.totalWeeks) continue;
      final weekdayIdx = day.weekday; // 1..7
      for (final c in courses) {
        if (slotsLeft <= 0) break;
        if (c.dayOfWeek != weekdayIdx) continue;
        if (!c.activeInWeek(week)) continue;
        final setting = reminders[c.id];
        // 默认全开:无 setting 视为已启用;只有 setting 存在且 enabled=false 才跳过
        if (setting != null && !setting.enabled) continue;
        final leadMinutes = setting?.leadMinutes ?? defaultLeadMinutes;
        final startStr = semester.sectionStart(c.startSection);
        final parts = startStr.split(':');
        if (parts.length != 2) continue;
        final hh = int.tryParse(parts[0]);
        final mm = int.tryParse(parts[1]);
        if (hh == null || mm == null) continue;
        final classTime = DateTime(day.year, day.month, day.day, hh, mm);
        final fire = classTime.subtract(Duration(minutes: leadMinutes));
        if (fire.isBefore(now)) continue;
        final fireTz = tz.TZDateTime.from(fire, tz.local);
        final id = _notifId('course_${c.id}', dayOffset);
        await _plugin.zonedSchedule(
          id,
          c.name,
          '$leadMinutes 分钟后于 ${semester.sectionStart(c.startSection)} 开始 · ${c.location}',
          fireTz,
          _details(),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'schedule://course?id=${Uri.encodeQueryComponent(c.id)}',
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        slotsLeft--;
      }
    }
    return slotsLeft;
  }

  static Future<void> cancelForEvent(String eventId) async {
    if (!_initialized) return;
    // 这里 cancelAll 也可以,但仅取消该 event 的更精准:遍历 pending 找匹配。
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      if (p.payload != null && p.payload!.contains('id=$eventId')) {
        await _plugin.cancel(p.id);
      }
    }
  }

  static DateTimeComponents? _matchFor(RecurrenceFreq freq) {
    return switch (freq) {
      RecurrenceFreq.daily => DateTimeComponents.time,
      RecurrenceFreq.weekly => DateTimeComponents.dayOfWeekAndTime,
      RecurrenceFreq.monthly => DateTimeComponents.dayOfMonthAndTime,
      RecurrenceFreq.yearly => DateTimeComponents.dateAndTime,
      RecurrenceFreq.none => null,
    };
  }

  static NotificationDetails _details() {
    return const NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  static String _bodyForEvent(EventItem e, Reminder rem) {
    final pieces = <String>[];
    if (rem.amount != 0) pieces.add(rem.label());
    if (e.location != null && e.location!.isNotEmpty) pieces.add(e.location!);
    if (e.note != null && e.note!.isNotEmpty) pieces.add(e.note!);
    return pieces.join(' · ');
  }

  static int _notifId(String key, int extra) {
    return (Object.hash(key, extra) & 0x7fffffff);
  }
}

/// 用于 Riverpod 监听日程/课程/课程提醒变化后触发重排,debounce 500ms。
class NotificationRescheduler {
  NotificationRescheduler({required this.run});

  final Future<void> Function() run;
  Timer? _timer;

  void requestReschedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () async {
      await run();
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// 提供 ChangeNotifier 风格的 hook,让 ScheduleApp 监听各 Hive box 的 watch。
class NotificationLifecycleObserver with WidgetsBindingObserver {
  NotificationLifecycleObserver(this.onResumed);

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}
