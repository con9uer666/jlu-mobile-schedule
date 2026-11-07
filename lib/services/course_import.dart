import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../data/course.dart';
import '../data/course_id.dart';
import '../data/raw_entry.dart';
import '../data/storage.dart';
import '../ui/course_colors.dart';

String _identity(
  String name,
  String teacher,
  int day,
  int start,
  int end,
  String location,
) =>
    jsonEncode([name.trim(), teacher.trim(), day, start, end, location.trim()]);

/// Reuse existing identities, including legacy positional IDs, only when they
/// still represent the same course. New courses never reuse positional IDs.
Future<void> importCourses(
  String semesterId,
  List<CourseRawEntry> entries,
) async {
  if (entries.isEmpty) throw const FormatException('未解析到课程，原课表未修改');
  final old = AppStorage.courses.values
      .where(
        (c) =>
            c.id.startsWith('$semesterId-') &&
            !isManualCourseId(semesterId, c.id),
      )
      .toList();
  final byIdentity = <String, Course>{};
  for (final course in old) {
    byIdentity.putIfAbsent(
      _identity(
        course.name,
        course.teacher,
        course.dayOfWeek,
        course.startSection,
        course.endSection,
        course.location,
      ),
      () => course,
    );
  }
  final grouped = <String, List<CourseRawEntry>>{};
  for (final entry in entries) {
    if (entry.dayOfWeek < 1 ||
        entry.dayOfWeek > 7 ||
        entry.startSection < 1 ||
        entry.endSection < entry.startSection ||
        entry.weeks.any((w) => w < 1)) {
      throw const FormatException('课表包含无效星期、节次或周次，未覆盖原课表');
    }
    grouped
        .putIfAbsent(
          _identity(
            entry.name,
            entry.teacher,
            entry.dayOfWeek,
            entry.startSection,
            entry.endSection,
            entry.location,
          ),
          () => [],
        )
        .add(entry);
  }
  final imported = <String, Course>{};
  for (final group in grouped.entries) {
    final entry = group.value.first;
    final previous = byIdentity[group.key];
    final id =
        previous?.id ??
        '$semesterId-import-${sha256.convert(utf8.encode(group.key))}';
    imported[id] = Course(
      id: id,
      name: entry.name,
      teacher: entry.teacher,
      location: entry.location,
      dayOfWeek: entry.dayOfWeek,
      startSection: entry.startSection,
      endSection: entry.endSection,
      weeks: group.value.expand((e) => e.weeks).toSet().toList()..sort(),
      colorIndex: previous?.colorIndex ?? CourseColors.stableIndex(entry.name),
      remark: previous?.remark,
    );
  }
  // Write replacements first. An interrupted import can be safely repeated.
  await AppStorage.courses.putAll(imported);
  final removed = old
      .where((c) => !imported.containsKey(c.id))
      .map((c) => c.id)
      .toSet();
  await AppStorage.overrides.deleteAll(
    AppStorage.overrides.values
        .where((o) => removed.contains(o.courseId))
        .map((o) => o.id)
        .toList(),
  );
  await AppStorage.courseReminders.deleteAll(removed);
  for (final item
      in AppStorage.studyItems.values
          .where((i) => removed.contains(i.courseId))
          .toList()) {
    item.courseId = null;
    await item.save();
  }
  await AppStorage.courses.deleteAll(removed);
}
