import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'course.dart';
import 'day_swap.dart';
import 'day_swap.g.dart';
import 'course.g.dart';
import 'course_override.dart';
import 'course_override.g.dart';
import 'course_reminder_setting.dart';
import 'event_item.dart';
import 'recurrence_rule.dart';
import 'reminder.dart';
import 'semester.dart';
import 'semester.g.dart';

class AppStorage {
  static const coursesBox = 'courses';
  static const semestersBox = 'semesters';
  static const settingsBox = 'settings';
  static const overridesBox = 'overrides';
  static const eventsBox = 'events';
  static const courseRemindersBox = 'course_reminders';
  static const daySwapsBox = 'day_swaps';

  static late Box<Course> courses;
  static late Box<Semester> semesters;
  static late Box settings;
  static late Box<CourseOverride> overrides;
  static late Box<EventItem> events;
  static late Box<CourseReminderSetting> courseReminders;
  static late Box<DaySwap> daySwaps;

  static Future<void> openAll() async {
    Hive.registerAdapter(CourseAdapter());
    Hive.registerAdapter(DaySwapAdapter());
    Hive.registerAdapter(SemesterAdapter());
    Hive.registerAdapter(CourseOverrideAdapter());
    Hive.registerAdapter(EventItemAdapter());
    Hive.registerAdapter(RecurrenceRuleAdapter());
    Hive.registerAdapter(RecurrenceFreqAdapter());
    Hive.registerAdapter(ReminderAdapter());
    Hive.registerAdapter(ReminderUnitAdapter());
    Hive.registerAdapter(CourseReminderSettingAdapter());

    courses = await Hive.openBox<Course>(coursesBox);
    semesters = await Hive.openBox<Semester>(semestersBox);
    settings = await Hive.openBox(settingsBox);
    overrides = await Hive.openBox<CourseOverride>(overridesBox);
    events = await Hive.openBox<EventItem>(eventsBox);
    courseReminders =
        await Hive.openBox<CourseReminderSetting>(courseRemindersBox);
    daySwaps = await Hive.openBox<DaySwap>(daySwapsBox);
  }
}
