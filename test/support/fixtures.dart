import 'package:schedule/data/course.dart';
import 'package:schedule/data/semester.dart';

Semester semester({int weeks = 2}) => Semester(
  id: 's',
  name: 'S',
  startDate: DateTime(2026, 9, 7),
  totalWeeks: weeks,
);
Course course({
  String id = 's-0',
  String name = '数学',
  int day = 1,
  List<int> weeks = const [1, 2],
  int start = 1,
  int end = 2,
  String location = 'A101',
}) => Course(
  id: id,
  name: name,
  teacher: '教师',
  location: location,
  dayOfWeek: day,
  startSection: start,
  endSection: end,
  weeks: weeks,
);
