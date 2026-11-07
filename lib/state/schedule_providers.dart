import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course.dart';
import '../data/course_id.dart';
import '../data/course_override.dart';
import '../data/day_swap.dart';
import '../data/semester.dart';
import '../data/storage.dart';
import '../services/course_schedule.dart';
export '../services/course_schedule.dart' show EffectiveCourse;

final currentSemesterProvider =
    StateNotifierProvider<CurrentSemesterController, Semester?>(
      (ref) => CurrentSemesterController(),
    );

class CurrentSemesterController extends StateNotifier<Semester?> {
  CurrentSemesterController() : super(null) {
    _load();
  }

  void _load() {
    final id = AppStorage.settings.get('currentSemesterId') as String?;
    if (id != null) {
      state = AppStorage.semesters.get(id);
    } else if (AppStorage.semesters.isNotEmpty) {
      state = AppStorage.semesters.values.first;
    }
    final semester = state;
    if (semester != null) {
      unawaited(_migrateLegacyManualCourses(semester));
    }
  }

  Future<void> setCurrent(Semester semester) async {
    await AppStorage.semesters.put(semester.id, semester);
    await AppStorage.settings.put('currentSemesterId', semester.id);
    state = semester;
    await _migrateLegacyManualCourses(semester);
  }

  Future<void> _migrateLegacyManualCourses(Semester semester) async {
    final legacyCourses = AppStorage.courses.values
        .where((course) => isLegacyManualCourseId(course.id))
        .toList();
    for (final old in legacyCourses) {
      final id = '${semester.id}-manual-${old.id}';
      if (!AppStorage.courses.containsKey(id)) {
        await AppStorage.courses.put(
          id,
          Course(
            id: id,
            name: old.name,
            teacher: old.teacher,
            location: old.location,
            dayOfWeek: old.dayOfWeek,
            startSection: old.startSection,
            endSection: old.endSection,
            weeks: List<int>.from(old.weeks),
            colorIndex: old.colorIndex,
            remark: old.remark,
          ),
        );
      }
      await AppStorage.courses.delete(old.id);
    }
  }
}

final currentWeekProvider = StateProvider<int>((ref) {
  final sem = ref.watch(currentSemesterProvider);
  if (sem == null) return 1;
  return sem.currentWeek(DateTime.now());
});

final coursesProvider = StreamProvider<List<Course>>((ref) async* {
  // 每个学期的课程以“学期 ID-序号”保存；界面只展示当前学期，
  // 避免导入多个学期后课程互相混在一起。
  final semester = ref.watch(currentSemesterProvider);
  List<Course> currentCourses() {
    if (semester == null) return const <Course>[];
    final prefix = '${semester.id}-';
    return AppStorage.courses.values
        .where((course) => course.id.startsWith(prefix))
        .toList();
  }

  yield currentCourses();
  await for (final _ in AppStorage.courses.watch()) {
    yield currentCourses();
  }
});

final overridesProvider = StreamProvider<List<CourseOverride>>((ref) async* {
  yield AppStorage.overrides.values.toList();
  await for (final _ in AppStorage.overrides.watch()) {
    yield AppStorage.overrides.values.toList();
  }
});

/// UI callers read day swaps from storage; calculation itself is shared and pure.
List<EffectiveCourse> effectiveCoursesForWeek(
  List<Course> courses,
  List<CourseOverride> overrides,
  int week, {
  required Semester semester,
  DateTime? weekStart,
}) => resolveWeekCourses(
  semester: semester,
  courses: courses,
  overrides: overrides,
  daySwaps: AppStorage.daySwaps.values.toList(),
  week: week,
);

final daySwapsProvider = StreamProvider<List<DaySwap>>((ref) async* {
  yield AppStorage.daySwaps.values.toList();
  await for (final _ in AppStorage.daySwaps.watch()) {
    yield AppStorage.daySwaps.values.toList();
  }
});
