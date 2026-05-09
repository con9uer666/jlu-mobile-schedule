import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'course.dart';
import 'course.g.dart';
import 'semester.dart';
import 'semester.g.dart';

class AppStorage {
  static const coursesBox = 'courses';
  static const semestersBox = 'semesters';
  static const settingsBox = 'settings';

  static late Box<Course> courses;
  static late Box<Semester> semesters;
  static late Box settings;

  static Future<void> openAll() async {
    Hive.registerAdapter(CourseAdapter());
    Hive.registerAdapter(SemesterAdapter());
    courses = await Hive.openBox<Course>(coursesBox);
    semesters = await Hive.openBox<Semester>(semestersBox);
    settings = await Hive.openBox(settingsBox);
  }
}
