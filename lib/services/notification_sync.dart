import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course_reminder_setting.dart';
import '../data/storage.dart';
import '../state/agenda_providers.dart';
import '../state/notification_settings_provider.dart';
import '../state/schedule_providers.dart';
import '../state/study_providers.dart';
import 'notification_service.dart';

class NotificationSync {
  NotificationSync._(this._ref) {
    _rescheduler = NotificationRescheduler(run: _run);
  }

  final Ref _ref;
  late final NotificationRescheduler _rescheduler;

  static NotificationSync attach(Ref ref) {
    final sync = NotificationSync._(ref);
    sync._start();
    return sync;
  }

  void refresh() => _rescheduler.requestReschedule();

  void _start() {
    _rescheduler.requestReschedule();
    _ref.listen(eventsProvider, (_, _) => _rescheduler.requestReschedule());
    _ref.listen(
      currentSemesterProvider,
      (_, _) => _rescheduler.requestReschedule(),
    );
    _ref.listen(coursesProvider, (_, _) => _rescheduler.requestReschedule());
    _ref.listen(overridesProvider, (_, _) => _rescheduler.requestReschedule());
    _ref.listen(studyItemsProvider, (_, _) => _rescheduler.requestReschedule());
    _ref.listen(
      notificationSettingsProvider,
      (_, _) => _rescheduler.requestReschedule(),
    );
    final reminders = AppStorage.courseReminders.watch().listen((_) {
      _rescheduler.requestReschedule();
    });
    final swaps = AppStorage.daySwaps.watch().listen((_) {
      _rescheduler.requestReschedule();
    });
    final timer = Timer.periodic(const Duration(hours: 1), (_) => refresh());
    _ref.onDispose(() {
      reminders.cancel();
      swaps.cancel();
      timer.cancel();
      _rescheduler.dispose();
    });
  }

  Future<void> _run() async {
    if (!NotificationService.isInitialized) return;
    final events = AppStorage.events.values.toList();
    final semester = _ref.read(currentSemesterProvider);
    // Hive 保留所有历史学期的课程。通知和课表页面必须使用同一套
    // 当前学期筛选，否则旧学期课程也会被排进未来通知。
    final courses = AppStorage.courses.values
        .where(
          (course) =>
              semester != null && course.id.startsWith('${semester.id}-'),
        )
        .toList();
    final notifSettings = _ref.read(notificationSettingsProvider);
    final Map<String, CourseReminderSetting> reminders = {
      for (final r in AppStorage.courseReminders.values) r.courseId: r,
    };
    await NotificationService.rescheduleAll(
      studyItems: AppStorage.studyItems.values.toList(),
      events: events,
      courses: courses,
      courseReminders: reminders,
      semester: semester,
      overrides: AppStorage.overrides.values.toList(),
      daySwaps: AppStorage.daySwaps.values.toList(),
      weeklyDigestEnabled: notifSettings.weeklyDigestEnabled,
      coursesGlobalEnabled: notifSettings.coursesEnabled,
      defaultCourseLeadMinutes: notifSettings.defaultLeadMinutes,
    );
  }
}

final notificationSyncProvider = Provider<NotificationSync>(
  NotificationSync.attach,
);
