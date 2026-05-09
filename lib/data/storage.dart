import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'course.dart';
import 'course.g.dart';
import 'course_override.dart';
import 'course_override.g.dart';
import 'semester.dart';
import 'semester.g.dart';

class AppStorage {
  static const coursesBox = 'courses';
  static const semestersBox = 'semesters';
  static const settingsBox = 'settings';
  static const overridesBox = 'overrides';

  static late Box<Course> courses;
  static late Box<Semester> semesters;
  static late Box settings;
  static late Box<CourseOverride> overrides;

  static Future<void> openAll() async {
    Hive.registerAdapter(CourseAdapter());
    Hive.registerAdapter(SemesterAdapter());
    Hive.registerAdapter(CourseOverrideAdapter());
    courses = await Hive.openBox<Course>(coursesBox);
    semesters = await Hive.openBox<Semester>(semestersBox);
    settings = await Hive.openBox(settingsBox);
    overrides = await Hive.openBox<CourseOverride>(overridesBox);
  }
}
