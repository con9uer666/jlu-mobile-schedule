import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course.dart';
import '../data/course_override.dart';
import '../data/semester.dart';
import '../data/storage.dart';

final currentSemesterProvider = StateNotifierProvider<CurrentSemesterController, Semester?>(
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
  }

  Future<void> setCurrent(Semester semester) async {
    await AppStorage.semesters.put(semester.id, semester);
    await AppStorage.settings.put('currentSemesterId', semester.id);
    state = semester;
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

/// 本周实际呈现的课程块(应用完临时调课/停课后的结果)。
class EffectiveCourse {
  EffectiveCourse({
    required this.course,
    required this.dayOfWeek,
    required this.startSection,
    required this.endSection,
    required this.location,
    required this.isAdjusted,
  });

  final Course course;
  final int dayOfWeek;
  final int startSection;
  final int endSection;
  final String location;
  final bool isAdjusted;
}

/// 合并 courses + overrides → 指定周该怎么摆。
/// 跳过 kindCancel;kindMove 覆盖 dayOfWeek / section / location。
List<EffectiveCourse> effectiveCoursesForWeek(
  List<Course> courses,
  List<CourseOverride> overrides,
  int week,
  {DateTime? weekStart}
) {
  final byCourse = <String, CourseOverride>{
    for (final o in overrides.where((o) => o.week == week)) o.courseId: o,
  };
  final out = <EffectiveCourse>[];
  for (final c in courses) {
    if (!c.activeInWeek(week)) continue;
    final o = byCourse[c.id];
    if (o != null && o.isCancel) continue;
    if (o != null && o.isMove) {
      out.add(EffectiveCourse(
        course: c,
        dayOfWeek: o.newDayOfWeek,
        startSection: o.newStartSection,
        endSection: o.newEndSection,
        location: (o.newLocation?.isNotEmpty ?? false) ? o.newLocation! : c.location,
        isAdjusted: true,
      ));
    } else {
      out.add(EffectiveCourse(
        course: c,
        dayOfWeek: c.dayOfWeek,
        startSection: c.startSection,
        endSection: c.endSection,
        location: c.location,
        isAdjusted: false,
      ));
    }
  }
  if (weekStart == null || AppStorage.daySwaps.isEmpty) return out;
  final swaps = <int, int>{};
  for (final s in AppStorage.daySwaps.values) {
    final d = DateTime(s.targetDate.year, s.targetDate.month, s.targetDate.day);
    final idx = d.difference(DateTime(weekStart.year, weekStart.month, weekStart.day)).inDays;
    if (idx >= 0 && idx < 7) swaps[idx + 1] = s.sourceWeekday;
  }
  if (swaps.isEmpty) return out;
  return out.where((e) => !swaps.containsKey(e.dayOfWeek)).map((e) {
    final target = swaps.entries.firstWhere((x) => x.value == e.dayOfWeek, orElse: () => const MapEntry(0, 0)).key;
    return target == 0 ? e : EffectiveCourse(course: e.course, dayOfWeek: target, startSection: e.startSection, endSection: e.endSection, location: e.location, isAdjusted: true);
  }).toList();
}
