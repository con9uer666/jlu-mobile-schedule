import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course_reminder_setting.dart';
import '../data/storage.dart';
import '../state/agenda_providers.dart';
import '../state/notification_settings_provider.dart';
import '../state/schedule_providers.dart';
import 'notification_service.dart';
import 'weekly_digest.dart';

class NotificationSync {
  NotificationSync._(this._ref) {
    _rescheduler = NotificationRescheduler(run: _run);
  }

  final Ref _ref;
  late final NotificationRescheduler _rescheduler;

  static void attach(Ref ref) {
    final sync = NotificationSync._(ref);
    sync._start();
  }

  void _start() {
    _rescheduler.requestReschedule();
    _ref.listen(eventsProvider, (_, _) => _rescheduler.requestReschedule());
    _ref.listen(currentSemesterProvider, (_, _) => _rescheduler.requestReschedule());
    _ref.listen(coursesProvider, (_, _) => _rescheduler.requestReschedule());
    _ref.listen(overridesProvider, (_, _) => _rescheduler.requestReschedule());
    _ref.listen(notificationSettingsProvider,
        (_, _) => _rescheduler.requestReschedule());
    AppStorage.courseReminders.watch().listen((_) {
      _rescheduler.requestReschedule();
    });
  }

  Future<void> _run() async {
    final events = AppStorage.events.values.toList();
    final courses = AppStorage.courses.values.toList();
    final semester = _ref.read(currentSemesterProvider);
    final notifSettings = _ref.read(notificationSettingsProvider);
    final Map<String, CourseReminderSetting> reminders = {
      for (final r in AppStorage.courseReminders.values) r.courseId: r,
    };
    await NotificationService.rescheduleAll(
      events: events,
      courses: courses,
      courseReminders: reminders,
      semester: semester,
      coursesGlobalEnabled: notifSettings.coursesEnabled,
      defaultCourseLeadMinutes: notifSettings.defaultLeadMinutes,
    );
    await WeeklyDigest.maybeSchedule(
      enabled: notifSettings.weeklyDigestEnabled,
      semester: semester,
    );
  }
}

final notificationSyncProvider = Provider<void>((ref) {
  NotificationSync.attach(ref);
});
