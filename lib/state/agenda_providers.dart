import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course_reminder_setting.dart';
import '../data/event_item.dart';
import '../data/storage.dart';

final eventsProvider = StreamProvider<List<EventItem>>((ref) async* {
  List<EventItem> snapshot() => AppStorage.events.values.toList();
  yield snapshot();
  await for (final _ in AppStorage.events.watch()) {
    yield snapshot();
  }
});

final eventsControllerProvider =
    Provider<EventsController>((ref) => EventsController());

class EventsController {
  Future<void> upsert(EventItem event) async {
    event.updatedAt = DateTime.now();
    await AppStorage.events.put(event.id, event);
  }

  Future<void> delete(String id) async {
    await AppStorage.events.delete(id);
  }
}

final courseReminderProvider =
    StreamProvider.family<CourseReminderSetting?, String>(
        (ref, courseId) async* {
  yield AppStorage.courseReminders.get(courseId);
  await for (final _ in AppStorage.courseReminders.watch(key: courseId)) {
    yield AppStorage.courseReminders.get(courseId);
  }
});

class CourseReminderController {
  Future<void> setEnabled(String courseId, bool enabled) async {
    final existing = AppStorage.courseReminders.get(courseId);
    await AppStorage.courseReminders.put(
      courseId,
      CourseReminderSetting(
        courseId: courseId,
        enabled: enabled,
        leadMinutes: existing?.leadMinutes ?? 10,
      ),
    );
  }

  Future<void> setLead(String courseId, int leadMinutes) async {
    final existing = AppStorage.courseReminders.get(courseId);
    await AppStorage.courseReminders.put(
      courseId,
      CourseReminderSetting(
        courseId: courseId,
        enabled: existing?.enabled ?? false,
        leadMinutes: leadMinutes,
      ),
    );
  }
}

final courseReminderControllerProvider =
    Provider<CourseReminderController>((ref) => CourseReminderController());
