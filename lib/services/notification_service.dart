import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/course.dart';
import '../data/course_reminder_setting.dart';
import '../data/event_item.dart';
import '../data/course_override.dart';
import '../data/day_swap.dart';
import '../data/semester.dart';
import '../data/study_item.dart';
import 'notification_plan.dart';

typedef DeepLinkHandler = void Function(Uri uri);

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static DeepLinkHandler? _deepLinkHandler;
  static bool _initialized = false;
  static Uri? _initialDeepLink;
  static bool _deepLinksReady = false;
  static AndroidScheduleMode _androidScheduleMode =
      AndroidScheduleMode.exactAllowWhileIdle;

  static bool get isInitialized => _initialized;

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
    const androidInit = AndroidInitializationSettings('ic_notification');
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: androidInit,
          iOS: darwinInit,
          macOS: darwinInit,
        ),
        onDidReceiveNotificationResponse: _onTap,
      );
      _initialized = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true && payload != null) {
        _initialDeepLink = Uri.tryParse(payload);
      }
    } catch (error, stackTrace) {
      // Notification setup must never prevent the schedule UI from opening.
      // This also keeps older installs usable if a platform resource is missing.
      debugPrint('Notification initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Uri? consumeInitialDeepLink() {
    _deepLinksReady = true;
    final link = _initialDeepLink;
    _initialDeepLink = null;
    return link;
  }

  static Future<bool> requestPermissions() async {
    if (!_initialized) return false;
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return false;
      final notificationsGranted =
          await android.requestNotificationsPermission() ?? true;
      try {
        await android.requestExactAlarmsPermission();
      } catch (_) {
        // Exact alarms are optional on older Android versions and on devices
        // that do not expose the permission flow.
      }
      await _refreshAndroidScheduleMode();
      return notificationsGranted;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final g = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return g ?? false;
    }
    final mac = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (mac != null) {
      final g = await mac.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return g ?? false;
    }
    return false;
  }

  static Future<bool> checkPermissionGranted() async {
    if (!_initialized) return false;
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.areNotificationsEnabled() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final s = await ios.checkPermissions();
      return s?.isEnabled ?? false;
    }
    final mac = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
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
    if (_deepLinksReady) {
      _deepLinkHandler?.call(uri);
    } else {
      _initialDeepLink = uri;
    }
  }

  /// Persist the nearest reminders for the whole semester, within OS limits.
  /// iOS allows 64 pending requests; Android has room for a longer queue.
  static Future<void> rescheduleAll({
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
  }) async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    if (!await checkPermissionGranted()) return;
    await _refreshAndroidScheduleMode();
    final plan = buildNotificationPlan(
      now: DateTime.now(),
      studyItems: studyItems,
      events: events,
      courses: courses,
      courseReminders: courseReminders,
      semester: semester,
      overrides: overrides,
      daySwaps: daySwaps,
      coursesGlobalEnabled: coursesGlobalEnabled,
      defaultCourseLeadMinutes: defaultCourseLeadMinutes,
      weeklyDigestEnabled: weeklyDigestEnabled,
      limit: Platform.isAndroid ? 400 : 64,
    );
    for (var i = 0; i < plan.length; i++) {
      final item = plan[i];
      if (!item.fireAt.isAfter(DateTime.now())) continue;
      // Unique within each complete replacement, including simultaneous reminders.
      await _plugin.zonedSchedule(
        1000 + i,
        item.title,
        item.body,
        tz.TZDateTime.from(item.fireAt, tz.local),
        _details(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: item.payload,
        androidScheduleMode: _androidScheduleMode,
      );
    }
  }

  static Future<void> cancelForEvent(String eventId) async {
    if (!_initialized) return;
    for (final p in await _plugin.pendingNotificationRequests()) {
      final uri = Uri.tryParse(p.payload ?? '');
      if (uri?.host == 'event' && uri?.queryParameters['id'] == eventId) {
        await _plugin.cancel(p.id);
      }
    }
  }

  static NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'schedule_reminders',
        '课程提醒',
        channelDescription: '课程、作业、考试和待办提醒',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
      ),
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

  static Future<void> _refreshAndroidScheduleMode() async {
    if (!Platform.isAndroid) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications();
    _androidScheduleMode = exact == false
        ? AndroidScheduleMode.inexactAllowWhileIdle
        : AndroidScheduleMode.exactAllowWhileIdle;
  }
}

/// 用于 Riverpod 监听日程/课程/课程提醒变化后触发重排。
/// 连续变化 debounce 500ms,原生通知操作期间则串行执行最新一轮。
class NotificationRescheduler {
  NotificationRescheduler({required this.run});

  final Future<void> Function() run;
  Timer? _timer;
  int _requestVersion = 0;
  bool _running = false;

  void requestReschedule() {
    _requestVersion++;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), _runLatest);
  }

  Future<void> _runLatest() async {
    if (_running) return;
    _running = true;
    final version = _requestVersion;
    try {
      await run();
    } catch (error, stackTrace) {
      // A notification plugin failure must not become an unhandled async
      // exception or prevent the rest of the app from being usable.
      debugPrint('Notification reschedule failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _running = false;
      // A change arrived while the previous native notification operation was
      // in flight. Run once more after it finishes, so an older snapshot can
      // never be the final set of scheduled notifications.
      if (_requestVersion != version) {
        _timer?.cancel();
        _timer = Timer(Duration.zero, _runLatest);
      }
    }
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
